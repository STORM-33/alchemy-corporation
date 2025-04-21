extends Control
## Enhanced HUD with quest tracking and daily goals

# Signals
signal scene_change_requested(scene_name)
signal inventory_toggled
signal recipe_book_toggled

# Onready variables
@onready var _gold_label = $TopBar/Resources/GoldPanel/GoldLabel
@onready var _essence_label = $TopBar/Resources/EssencePanel/EssenceLabel
@onready var _level_label = $TopBar/PlayerInfo/LevelLabel
@onready var _inventory_button = $BottomBar/InventoryButton
@onready var _recipe_button = $BottomBar/RecipeButton
@onready var _workshop_button = $BottomBar/NavButtons/WorkshopButton
@onready var _garden_button = $BottomBar/NavButtons/GardenButton
@onready var _forest_button = $BottomBar/NavButtons/ForestButton
@onready var _notification_container = $NotificationArea
@onready var _quest_panel = $SideBar/QuestPanel
@onready var _daily_goals_container = $SideBar/QuestPanel/DailyGoals/GoalsContainer
@onready var _current_orders_container = $SideBar/QuestPanel/VillagerOrders/OrdersContainer
@onready var _help_button = $TopBar/HelpButton

# Private variables
var _current_scene = "workshop"
var _notifications = []
var _notification_timer = null
var _daily_goals = []
var _current_orders = []
var _quest_panel_visible = true

# Lifecycle methods
func _ready():
	# Connect button signals
	_inventory_button.pressed.connect(_on_inventory_button_pressed)
	_recipe_button.pressed.connect(_on_recipe_button_pressed)
	_workshop_button.pressed.connect(_on_workshop_button_pressed)
	_garden_button.pressed.connect(_on_garden_button_pressed)
	_forest_button.pressed.connect(_on_forest_button_pressed)
	_help_button.pressed.connect(_on_help_button_pressed)
	
	# Connect quest panel toggle
	if has_node("SideBar/QuestPanelToggle"):
		get_node("SideBar/QuestPanelToggle").pressed.connect(_toggle_quest_panel)
	
	# Create notification timer
	_notification_timer = Timer.new()
	_notification_timer.wait_time = 0.1  # Check every 0.1 seconds
	_notification_timer.autostart = true
	_notification_timer.timeout.connect(_process_notifications)
	add_child(_notification_timer)
	
	# Update initial UI
	_update_resources_display()
	_update_level_display()
	_update_active_scene_button()
	
	# Connect to GameManager signals
	if has_node("/root/GameManager"):
		var game_manager = get_node("/root/GameManager")
		game_manager.game_initialized.connect(_update_all_displays)
		game_manager.game_loaded.connect(_update_all_displays)
		game_manager.game_day_passed.connect(_on_game_day_passed)
	
	# Setup daily goals (temporary examples)
	_setup_example_goals()
	_refresh_daily_goals_display()
	
	# Setup villager orders (temporary examples)
	_setup_example_orders()
	_refresh_orders_display()

# Public methods
func update_current_scene(scene_name):
	"""Updates UI to reflect the current scene"""
	_current_scene = scene_name
	_update_active_scene_button()

func update_gold_display(amount=null):
	"""Updates the gold display"""
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return
	
	if amount == null:
		amount = game_manager.player_gold
	
	if _gold_label:
		_gold_label.text = str(amount)

func update_essence_display(amount=null):
	"""Updates the essence display"""
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return
	
	if amount == null:
		amount = game_manager.player_essence
	
	if _essence_label:
		_essence_label.text = str(amount)

func show_notification(message, duration=3.0, type="normal"):
	"""Shows a notification message"""
	_notifications.append({
		"message": message,
		"duration": duration,
		"type": type,
		"created_at": Time.get_unix_time_from_system()
	})

func add_daily_goal(title, description, progress=0, max_progress=1, reward={"gold": 5}):
	"""Adds a daily goal to the quest panel"""
	var goal_id = "goal_" + str(Time.get_unix_time_from_system())
	
	var goal = {
		"id": goal_id,
		"title": title,
		"description": description,
		"progress": progress,
		"max_progress": max_progress,
		"completed": progress >= max_progress,
		"reward": reward
	}
	
	_daily_goals.append(goal)
	_refresh_daily_goals_display()
	
	return goal_id

func update_goal_progress(goal_id, progress):
	"""Updates the progress of a specific goal"""
	for goal in _daily_goals:
		if goal.id == goal_id:
			goal.progress = min(progress, goal.max_progress)
			goal.completed = goal.progress >= goal.max_progress
			
			# Award rewards if newly completed
			if goal.completed and goal.progress == progress:
				_award_goal_reward(goal)
				
			_refresh_daily_goals_display()
			return true
	
	return false

func add_villager_order(villager_name, item_id, quantity=1, reward={"gold": 10}, time_limit=1440):
	"""Adds a villager order to the quest panel"""
	var order_id = "order_" + str(Time.get_unix_time_from_system())
	
	var order = {
		"id": order_id,
		"villager_name": villager_name,
		"item_id": item_id,
		"quantity": quantity,
		"fulfilled": 0,
		"completed": false,
		"reward": reward,
		"time_limit": time_limit,  # In minutes
		"time_remaining": time_limit
	}
	
	_current_orders.append(order)
	_refresh_orders_display()
	
	return order_id

func update_order_progress(order_id, fulfilled):
	"""Updates the progress of a specific villager order"""
	for order in _current_orders:
		if order.id == order_id:
			order.fulfilled = min(fulfilled, order.quantity)
			order.completed = order.fulfilled >= order.quantity
			
			# Award rewards if newly completed
			if order.completed and order.fulfilled == fulfilled:
				_award_order_reward(order)
				
			_refresh_orders_display()
			return true
	
	return false

# Private methods
func _update_resources_display():
	"""Updates the gold and essence displays"""
	update_gold_display()
	update_essence_display()

func _update_level_display():
	"""Updates the player level display"""
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager or not _level_label:
		return
	
	_level_label.text = "Level " + str(game_manager.player_level)

func _update_active_scene_button():
	"""Updates the navigation buttons to show which scene is active"""
	# Reset all buttons
	for button in [$BottomBar/NavButtons/WorkshopButton, 
				   $BottomBar/NavButtons/GardenButton, 
				   $BottomBar/NavButtons/ForestButton]:
		if button:
			button.disabled = false
			button.modulate = Color(0.8, 0.8, 0.8)  # Dimmed
	
	# Highlight active button
	var active_button = null
	match _current_scene:
		"workshop":
			active_button = _workshop_button
		"garden":
			active_button = _garden_button
		"forest_edge":
			active_button = _forest_button
	
	if active_button:
		active_button.disabled = true
		active_button.modulate = Color(1, 1, 1)  # Full brightness

func _update_all_displays():
	"""Updates all UI displays"""
	_update_resources_display()
	_update_level_display()
	_update_active_scene_button()
	_refresh_daily_goals_display()
	_refresh_orders_display()

func _process_notifications():
	"""Processes and displays notifications"""
	if _notifications.is_empty():
		return
	
	# Process each notification
	var current_time = Time.get_unix_time_from_system()
	var notifications_to_remove = []
	
	for i in range(_notifications.size()):
		var notification = _notifications[i]
		var age = current_time - notification.created_at
		
		# Check if notification should be shown
		if age < notification.duration:
			# Ensure the notification is displayed
			_ensure_notification_displayed(notification, i)
		else:
			# Mark for removal
			notifications_to_remove.append(i)
	
	# Remove expired notifications (in reverse order to maintain indices)
	for i in range(notifications_to_remove.size() - 1, -1, -1):
		var index = notifications_to_remove[i]
		_remove_notification_display(index)
		_notifications.remove_at(index)

func _ensure_notification_displayed(notification, index):
	"""Ensures a notification is displayed properly"""
	# Check if notification already has a display
	var notification_id = "notification_" + str(index)
	var existing = _notification_container.get_node_or_null(notification_id)
	
	if existing:
		# Already displayed
		return
	
	# Create new notification label
	var label = Label.new()
	label.name = notification_id
	label.text = notification.message
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Style based on type
	match notification.type:
		"success":
			label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		"warning":
			label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.1))
		"error":
			label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
		_:  # normal
			label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	
	# Add to container
	_notification_container.add_child(label)

func _remove_notification_display(index):
	"""Removes a notification's display element"""
	var notification_id = "notification_" + str(index)
	var existing = _notification_container.get_node_or_null(notification_id)
	
	if existing:
		existing.queue_free()

func _setup_example_goals():
	"""Sets up example daily goals for testing"""
	_daily_goals = [
		{
			"id": "goal_1",
			"title": "Gather Ingredients",
			"description": "Gather 5 different ingredients",
			"progress": 2,
			"max_progress": 5,
			"completed": false,
			"reward": {"gold": 10}
		},
		{
			"id": "goal_2",
			"title": "Brew Potions",
			"description": "Brew 3 potions of any type",
			"progress": 1,
			"max_progress": 3,
			"completed": false,
			"reward": {"gold": 15, "essence": 1}
		},
		{
			"id": "goal_3",
			"title": "Complete Villager Orders",
			"description": "Complete 2 villager orders",
			"progress": 0,
			"max_progress": 2,
			"completed": false,
			"reward": {"gold": 20, "essence": 2}
		}
	]

func _setup_example_orders():
	"""Sets up example villager orders for testing"""
	_current_orders = [
		{
			"id": "order_1",
			"villager_name": "Farmer Giles",
			"item_id": "pot_minor_healing",
			"quantity": 2,
			"fulfilled": 0,
			"completed": false,
			"reward": {"gold": 12},
			"time_limit": 1440,  # 24 hours in minutes
			"time_remaining": 1200  # 20 hours in minutes
		},
		{
			"id": "order_2",
			"villager_name": "Blacksmith Hilda",
			"item_id": "pot_cooling_salve",
			"quantity": 1,
			"fulfilled": 0,
			"completed": false,
			"reward": {"gold": 15, "essence": 1},
			"time_limit": 2880,  # 48 hours in minutes
			"time_remaining": 2400  # 40 hours in minutes
		}
	]

func _refresh_daily_goals_display():
	"""Updates the daily goals display in the quest panel"""
	# Clear existing goals
	for child in _daily_goals_container.get_children():
		child.queue_free()
	
	# Add each goal
	for goal in _daily_goals:
		var goal_panel = Panel.new()
		goal_panel.custom_minimum_size = Vector2(0, 70)
		goal_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var layout = VBoxContainer.new()
		layout.anchor_right = 1.0
		layout.anchor_bottom = 1.0
		layout.offset_left = 5
		layout.offset_top = 5
		layout.offset_right = -5
		layout.offset_bottom = -5
		goal_panel.add_child(layout)
		
		# Title with completion status
		var title_row = HBoxContainer.new()
		layout.add_child(title_row)
		
		var title = Label.new()
		title.text = goal.title
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(title)
		
		var status = Label.new()
		status.text = str(goal.progress) + "/" + str(goal.max_progress)
		title_row.add_child(status)
		
		# Description
		var description = Label.new()
		description.text = goal.description
		description.autowrap_mode = 3  # Enable text wrapping
		description.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		layout.add_child(description)
		
		# Progress bar
		var progress_bar = ProgressBar.new()
		progress_bar.value = float(goal.progress) / goal.max_progress * 100
		layout.add_child(progress_bar)
		
		# Visual state based on completion
		if goal.completed:
			goal_panel.add_theme_color_override("panel_color", Color(0.2, 0.5, 0.2, 0.7))
			title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
			progress_bar.value = 100
		
		_daily_goals_container.add_child(goal_panel)

func _refresh_orders_display():
	"""Updates the villager orders display in the quest panel"""
	# Clear existing orders
	for child in _current_orders_container.get_children():
		child.queue_free()
	
	# Add each order
	for order in _current_orders:
		var order_panel = Panel.new()
		order_panel.custom_minimum_size = Vector2(0, 80)
		order_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var layout = VBoxContainer.new()
		layout.anchor_right = 1.0
		layout.anchor_bottom = 1.0
		layout.offset_left = 5
		layout.offset_top = 5
		layout.offset_right = -5
		layout.offset_bottom = -5
		order_panel.add_child(layout)
		
		# Villager name
		var header = Label.new()
		header.text = order.villager_name
		header.add_theme_font_size_override("font_size", 16)
		layout.add_child(header)
		
		# Item requested
		var item_name = _get_item_name(order.item_id)
		var request = Label.new()
		request.text = "Wants: " + item_name + " x" + str(order.quantity)
		layout.add_child(request)
		
		# Reward
		var reward_text = "Reward: "
		if order.reward.has("gold"):
			reward_text += str(order.reward.gold) + " gold"
		if order.reward.has("essence"):
			reward_text += ", " + str(order.reward.essence) + " essence"
		
		var reward = Label.new()
		reward.text = reward_text
		layout.add_child(reward)
		
		# Time remaining
		var time = Label.new()
		time.text = "Time: " + _format_time_remaining(order.time_remaining)
		layout.add_child(time)
		
		# Visual state based on completion
		if order.completed:
			order_panel.add_theme_color_override("panel_color", Color(0.2, 0.5, 0.2, 0.7))
			header.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		elif order.time_remaining < 60:  # Less than 1 hour
			order_panel.add_theme_color_override("panel_color", Color(0.5, 0.2, 0.2, 0.7))
			time.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		
		_current_orders_container.add_child(order_panel)

func _get_item_name(item_id):
	"""Gets the name of an item from its ID"""
	# Check if this is a potion
	if item_id.begins_with("pot_"):
		var recipe_manager = get_node_or_null("/root/RecipeManager")
		if recipe_manager:
			var potion = recipe_manager.get_potion(item_id)
			if potion:
				return potion.name
	
	# Check if this is an ingredient
	elif item_id.begins_with("ing_"):
		var ingredient_manager = get_node_or_null("/root/IngredientManager")
		if ingredient_manager:
			var ingredient = ingredient_manager.get_ingredient(item_id)
			if ingredient:
				return ingredient.name
	
	return "Unknown Item"

func _format_time_remaining(minutes):
	"""Formats time remaining in minutes to a readable string"""
	if minutes < 60:
		return str(minutes) + " minutes"
	elif minutes < 1440:
		var hours = floor(minutes / 60)
		var mins = minutes % 60
		return str(hours) + "h " + str(mins) + "m"
	else:
		var days = floor(minutes / 1440)
		var hours = floor((minutes % 1440) / 60)
		return str(days) + "d " + str(hours) + "h"

func _award_goal_reward(goal):
	"""Awards the rewards for completing a goal"""
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return
	
	if goal.reward.has("gold"):
		game_manager.add_gold(goal.reward.gold)
	
	if goal.reward.has("essence"):
		game_manager.add_essence(goal.reward.essence)
	
	# Show a notification
	var reward_text = ""
	if goal.reward.has("gold"):
		reward_text += str(goal.reward.gold) + " gold"
	if goal.reward.has("essence"):
		if reward_text != "":
			reward_text += ", "
		reward_text += str(goal.reward.essence) + " essence"
	
	show_notification("Goal Completed: " + goal.title + "\nReward: " + reward_text, 5.0, "success")

func _award_order_reward(order):
	"""Awards the rewards for completing a villager order"""
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return
	
	if order.reward.has("gold"):
		game_manager.add_gold(order.reward.gold)
	
	if order.reward.has("essence"):
		game_manager.add_essence(order.reward.essence)
	
	# Show a notification
	var reward_text = ""
	if order.reward.has("gold"):
		reward_text += str(order.reward.gold) + " gold"
	if order.reward.has("essence"):
		if reward_text != "":
			reward_text += ", "
		reward_text += str(order.reward.essence) + " essence"
	
	show_notification("Order Completed for " + order.villager_name + "!\nReward: " + reward_text, 5.0, "success")

func _toggle_quest_panel():
	"""Toggles the visibility of the quest panel"""
	_quest_panel_visible = !_quest_panel_visible
	
	if _quest_panel:
		_quest_panel.visible = _quest_panel_visible

func _on_game_day_passed(day_number):
	"""Called when a game day passes"""
	# Refresh daily goals
	_setup_example_goals()  # Replace with real goal generation
	_refresh_daily_goals_display()
	
	# Update order times
	for order in _current_orders:
		order.time_remaining -= 1440  # Subtract one day in minutes
		
		# Remove expired orders
		if order.time_remaining <= 0 and not order.completed:
			# Show a notification for expired orders
			show_notification("Order from " + order.villager_name + " has expired!", 5.0, "warning")
	
	# Remove expired orders
	_current_orders = _current_orders.filter(func(order): return order.time_remaining > 0 or order.completed)
	
	# Add new orders
	# This would be implemented in a real system
	
	_refresh_orders_display()
	
	# Show day notification
	show_notification("Day " + str(day_number) + " has begun!", 5.0, "info")

func _on_inventory_button_pressed():
	"""Toggles the inventory panel"""
	inventory_toggled.emit()

func _on_recipe_button_pressed():
	"""Toggles the recipe book panel"""
	recipe_book_toggled.emit()

func _on_workshop_button_pressed():
	"""Switches to workshop scene"""
	if _current_scene != "workshop":
		scene_change_requested.emit("workshop")

func _on_garden_button_pressed():
	"""Switches to garden scene"""
	if _current_scene != "garden":
		scene_change_requested.emit("garden")

func _on_forest_button_pressed():
	"""Switches to forest scene"""
	if _current_scene != "forest_edge":
		scene_change_requested.emit("forest_edge")

func _on_help_button_pressed():
	"""Shows the tutorial or help panel"""
	var tutorial_system = get_node_or_null("/root/TutorialSystem")
	if tutorial_system:
		tutorial_system.start_tutorial()
