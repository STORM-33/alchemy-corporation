extends Control
## Main Heads-Up Display (HUD) for game UI

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

# Private variables
var _current_scene = "workshop"
var _notifications = []
var _notification_timer = null

# Lifecycle methods
func _ready():
	# Connect button signals
	_inventory_button.pressed.connect(_on_inventory_button_pressed)
	_recipe_button.pressed.connect(_on_recipe_button_pressed)
	_workshop_button.pressed.connect(_on_workshop_button_pressed)
	_garden_button.pressed.connect(_on_garden_button_pressed)
	_forest_button.pressed.connect(_on_forest_button_pressed)
	
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

func _process_notifications():
	"""Processes and displays notifications"""
	if _notifications.isEmpty():
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
