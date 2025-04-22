extends Node
## Connects all gameplay systems together to create the core gameplay loop
## Place this in scripts/autoload/gameplay_manager.gd and add to AutoLoad in Project Settings

# Signals
signal gameplay_initialized
signal resource_gathered(resource_id, amount)
signal potion_brewed(potion_id, quality)
signal order_fulfilled(villager_name, order_id, reward)
signal daily_goal_completed(goal_id, reward)

# Dragging ingredients from inventory
var dragging_ingredient = null  # Set when dragging from inventory to cauldron

# Current UI states
var inventory_panel_open = false
var recipe_book_open = false
var villager_panel_open = false
var shop_panel_open = false

# Lifecycle methods
func _ready():
	# Connect to the necessary systems
	_connect_signals()
	
	call_deferred("_initialize_gameplay")

# Public methods for core gameplay actions
func gather_resource(resource_id, amount=1):
	"""Called when a resource is gathered by the player"""
	var inventory_manager = get_node_or_null("/root/InventoryManager")
	if inventory_manager:
		inventory_manager.add_item(resource_id, amount)
		
		# Update any gathering goals
		var daily_goal_system = get_node_or_null("/root/DailyGoalSystem")
		if daily_goal_system and daily_goal_system.has_method("update_gathering_progress"):
			daily_goal_system.update_gathering_progress(resource_id, amount)
		
		resource_gathered.emit(resource_id, amount)
		return true
	return false

func brew_potion(potion_id, quality=1.0):
	"""Called when a potion is successfully brewed"""
	# Update brewing goals
	var daily_goal_system = get_node_or_null("/root/DailyGoalSystem")
	if daily_goal_system and daily_goal_system.has_method("update_brewing_progress"):
		daily_goal_system.update_brewing_progress(potion_id, 1)
	
	# Check if this potion fulfills any villager orders
	var villager_order_system = get_node_or_null("/root/VillagerOrderSystem")
	if villager_order_system and villager_order_system.has_method("check_order_fulfillment"):
		var matching_orders = villager_order_system.check_order_fulfillment(potion_id)
		
		# Notify about matching orders
		if not matching_orders.is_empty():
			var notification_system = get_node_or_null("/root/NotificationSystem")
			if notification_system:
				notification_system.show_info("You brewed a potion that matches an order!")
	
	potion_brewed.emit(potion_id, quality)
	return true

func fulfill_order(villager_name, order_id, potion_id):
	"""Fulfills a villager order with a potion"""
	var villager_order_system = get_node_or_null("/root/VillagerOrderSystem") 
	var inventory_manager = get_node_or_null("/root/InventoryManager")
	
	if not villager_order_system or not inventory_manager:
		return false
	
	# Get order details
	var order = villager_order_system.get_order(villager_name, order_id)
	if not order or order.item_id != potion_id:
		return false
	
	# Check if we have the potion
	if not inventory_manager.has_item(potion_id):
		return false
	
	# Remove potion from inventory
	inventory_manager.remove_item(potion_id, 1)
	
	# Complete order
	if villager_order_system.has_method("complete_order"):
		var reward = villager_order_system.complete_order(villager_name, order_id)
		
		if reward:
			# Award player
			var game_manager = get_node_or_null("/root/GameManager")
			if game_manager:
				if reward.has("gold"):
					game_manager.add_gold(reward.gold)
				if reward.has("essence"):
					game_manager.add_essence(reward.essence)
			
			# Update order goals
			var daily_goal_system = get_node_or_null("/root/DailyGoalSystem")
			if daily_goal_system and daily_goal_system.has_method("update_order_progress"):
				daily_goal_system.update_order_progress(1, villager_name)
				
			order_fulfilled.emit(villager_name, order_id, reward)
			return true
	
	return false

func claim_daily_goal_reward(goal_id):
	"""Claims a completed daily goal reward"""
	var daily_goal_system = get_node_or_null("/root/DailyGoalSystem")
	if not daily_goal_system or not daily_goal_system.has_method("complete_goal"):
		return false
		
	# Get and claim reward
	var reward = daily_goal_system.complete_goal(goal_id)
	if not reward:
		return false
		
	# Give rewards to player
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		if reward.has("gold"):
			game_manager.add_gold(reward.gold)
		if reward.has("essence"):
			game_manager.add_essence(reward.essence)
			
	daily_goal_completed.emit(goal_id, reward)
	return true

func start_ingredient_drag(ingredient_id):
	"""Starts dragging an ingredient"""
	dragging_ingredient = ingredient_id
	
func end_ingredient_drag(success=false):
	"""Ends dragging an ingredient"""
	if not success and dragging_ingredient:
		# The drag was canceled without being used
		# Could play a sound or show an effect
		pass
		
	dragging_ingredient = null
	
func drop_ingredient_on_cauldron():
	"""Attempts to drop the dragged ingredient on the cauldron"""
	if not dragging_ingredient:
		return false
		
	var main_scene = get_tree().current_scene
	if not main_scene:
		return false
		
	# Find the cauldron
	var cauldron
	var workshop = main_scene.get_node_or_null("Workshop")
	if workshop:
		cauldron = workshop.get_node_or_null("Stations/Cauldron")
	else:
		# Try to find cauldron directly in scene
		cauldron = main_scene.get_node_or_null("Cauldron")
	
	if not cauldron or not cauldron.has_method("add_ingredient"):
		end_ingredient_drag(false)
		return false
		
	# Add ingredient to cauldron
	var success = cauldron.add_ingredient(dragging_ingredient)
	
	if success:
		# Remove from inventory (only if added successfully)
		var inventory_manager = get_node_or_null("/root/InventoryManager")
		if inventory_manager:
			inventory_manager.remove_item(dragging_ingredient, 1)
	
	end_ingredient_drag(success)
	return success
		
func toggle_inventory_panel():
	"""Toggles the inventory panel visibility"""
	inventory_panel_open = !inventory_panel_open
	
	var main_scene = get_tree().current_scene
	if not main_scene:
		return
		
	# Find the inventory panel
	var inventory_panel = main_scene.get_node_or_null("UILayer/InventoryPanel")
	if not inventory_panel:
		# Try finding it directly in the scene
		inventory_panel = main_scene.get_node_or_null("InventoryPanel")
	
	if inventory_panel:
		if inventory_panel_open:
			if inventory_panel.has_method("show_panel"):
				inventory_panel.show_panel()
			else:
				inventory_panel.visible = true
		else:
			if inventory_panel.has_method("hide_panel"):
				inventory_panel.hide_panel()
			else:
				inventory_panel.visible = false

func toggle_recipe_book():
	"""Toggles the recipe book visibility"""
	recipe_book_open = !recipe_book_open
	
	var main_scene = get_tree().current_scene
	if not main_scene:
		return
		
	# Find the recipe book
	var recipe_book = main_scene.get_node_or_null("UILayer/RecipeBookPanel")
	if not recipe_book:
		# Try finding it directly in the scene
		recipe_book = main_scene.get_node_or_null("RecipeBookPanel")
	
	if recipe_book:
		if recipe_book_open:
			if recipe_book.has_method("show_panel"):
				recipe_book.show_panel()
			else:
				recipe_book.visible = true
		else:
			if recipe_book.has_method("hide_panel"):
				recipe_book.hide_panel()
			else:
				recipe_book.visible = false

func toggle_villager_panel():
	"""Toggles the villager order panel visibility"""
	villager_panel_open = !villager_panel_open
	
	var main_scene = get_tree().current_scene
	if not main_scene:
		return
		
	# Find the villager panel
	var villager_panel = main_scene.get_node_or_null("UILayer/VillagerOrderPanel")
	if not villager_panel:
		# Try finding it directly in the scene
		villager_panel = main_scene.get_node_or_null("VillagerOrderPanel")
	
	if villager_panel:
		villager_panel.visible = villager_panel_open
		
func generate_new_orders(count=1):
	"""Generates new villager orders"""
	var villager_order_system = get_node_or_null("/root/VillagerOrderSystem")
	if not villager_order_system or not villager_order_system.has_method("generate_orders"):
		return []
		
	var new_orders = villager_order_system.generate_orders(count)
	
	# Notify player
	if not new_orders.is_empty():
		var notification_system = get_node_or_null("/root/NotificationSystem") 
		if notification_system:
			notification_system.show_info("New villager orders available!")
			
	return new_orders

# Private methods
func _connect_signals():
	"""Connects signals from various systems"""
	# Connect to GatheringSystem for resource gathering
	var gathering_system = get_node_or_null("/root/GatheringSystem")
	if gathering_system and gathering_system.has_signal("resource_gathered"):
		if not gathering_system.resource_gathered.is_connected(_on_resource_gathered):
			gathering_system.resource_gathered.connect(_on_resource_gathered)
	
	# Connect to daily goals system
	var daily_goal_system = get_node_or_null("/root/DailyGoalSystem")
	if daily_goal_system and daily_goal_system.has_signal("goal_completed"):
		if not daily_goal_system.goal_completed.is_connected(_on_goal_completed):
			daily_goal_system.goal_completed.connect(_on_goal_completed)
			
	# Connect to HUD buttons for inventory, recipes, etc.
	_connect_to_hud()

func _initialize_gameplay():
	"""Initializes the gameplay systems"""
	await get_tree().process_frame
	
	# Find and connect to workshop/cauldron signals
	_connect_to_workshop()
	
	# Generate initial daily goals if needed
	var daily_goal_system = get_node_or_null("/root/DailyGoalSystem")
	if daily_goal_system and daily_goal_system.get_all_goals().is_empty():
		_initialize_daily_goals()
	
	# Generate initial villager orders if needed
	var villager_order_system = get_node_or_null("/root/VillagerOrderSystem")
	if villager_order_system and villager_order_system.get_all_orders().is_empty():
		generate_new_orders(3)  # Start with 3 orders
	
	gameplay_initialized.emit()

func _connect_to_workshop():
	"""Connects to the cauldron brewing signals"""
	await get_tree().process_frame  # Wait for scenes to initialize
	
	var main_scene = get_tree().current_scene
	if not main_scene:
		return
		
	# Try to find the cauldron in different possible locations
	var cauldron
	var workshop = main_scene.get_node_or_null("Workshop")
	if workshop:
		cauldron = workshop.get_node_or_null("Stations/Cauldron")
	
	if not cauldron:
		# Try direct path
		cauldron = main_scene.get_node_or_null("Cauldron")
	
	if cauldron and cauldron.has_signal("brewing_completed"):
		if not cauldron.brewing_completed.is_connected(_on_brewing_completed):
			cauldron.brewing_completed.connect(_on_brewing_completed)

func _connect_to_hud():
	"""Connects to HUD button signals"""
	await get_tree().process_frame
	
	var main_scene = get_tree().current_scene
	if not main_scene:
		return
		
	# Try to find HUD in different possible locations
	var hud = main_scene.get_node_or_null("UILayer/HUD")
	if not hud:
		hud = main_scene.get_node_or_null("HUD")
		
	if hud:
		# Connect to inventory button
		if hud.has_signal("inventory_toggled"):
			if not hud.inventory_toggled.is_connected(toggle_inventory_panel):
				hud.inventory_toggled.connect(toggle_inventory_panel)
		
		# Connect to recipe book button
		if hud.has_signal("recipe_book_toggled"):
			if not hud.recipe_book_toggled.is_connected(toggle_recipe_book):
				hud.recipe_book_toggled.connect(toggle_recipe_book)

func _initialize_daily_goals():
	"""Creates initial daily goals"""
	var daily_goal_system = get_node_or_null("/root/DailyGoalSystem")
	if not daily_goal_system:
		return
		
	# Create one goal of each type
	if daily_goal_system.has_method("create_gathering_goal"):
		daily_goal_system.create_gathering_goal("any", 5, {"gold": 10})
		
	if daily_goal_system.has_method("create_brewing_goal"):
		daily_goal_system.create_brewing_goal("any", 3, {"gold": 15, "essence": 1})
		
	if daily_goal_system.has_method("create_order_goal"):
		daily_goal_system.create_order_goal("", 2, {"gold": 20, "essence": 2})

# Signal handlers
func _on_resource_gathered(resource_id, node_id):
	"""Called when a resource is gathered via GatheringSystem"""
	gather_resource(resource_id)

func _on_brewing_completed(potion_id, potion_name, quality):
	"""Called when a potion is successfully brewed"""
	brew_potion(potion_id, quality)

func _on_goal_completed(goal_id, reward):
	"""Called when a goal is completed via DailyGoalSystem"""
	# The reward is handled by claim_daily_goal_reward, which is called
	# when the player clicks the claim button, not automatically here
	pass

func _on_game_day_changed(day_number):
	"""Called when a new day begins"""
	# Reset and create new daily goals
	var daily_goal_system = get_node_or_null("/root/DailyGoalSystem")
	if daily_goal_system and daily_goal_system.has_method("reset_daily_goals"):
		daily_goal_system.reset_daily_goals()
		_initialize_daily_goals()
	
	# Remove expired orders and generate new ones
	var villager_order_system = get_node_or_null("/root/VillagerOrderSystem")
	if villager_order_system:
		if villager_order_system.has_method("remove_expired_orders"):
			villager_order_system.remove_expired_orders()
		
		# Generate 2-3 new orders
		var new_order_count = randi() % 2 + 2  # 2-3
		generate_new_orders(new_order_count)
