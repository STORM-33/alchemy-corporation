extends Control
## Main Heads-Up Display (HUD) for game UI

# Signals
signal scene_change_requested(scene_name)

# Onready variables
@onready var _gold_label = $TopBar/Resources/GoldPanel/GoldLabel
@onready var _essence_label = $TopBar/Resources/EssencePanel/EssenceLabel
@onready var _level_label = $TopBar/PlayerInfo/LevelLabel
@onready var _inventory_button = $BottomBar/InventoryButton
@onready var _workshop_button = $BottomBar/NavButtons/WorkshopButton
@onready var _garden_button = $BottomBar/NavButtons/GardenButton
@onready var _forest_button = $BottomBar/NavButtons/ForestButton
@onready var _inventory_panel = $InventoryPanel
@onready var _recipe_book = $RecipeBookPanel

# Private variables
var _current_scene = "workshop"

# Lifecycle methods
func _ready():
	# Connect button signals
	_inventory_button.pressed.conncet(_on_inventory_button_pressed)
	_workshop_button.pressed.conncet(_on_workshop_button_pressed)
	_garden_button.pressed.conncet(_on_garden_button_pressed)
	_forest_button.pressed.conncet(_on_forest_button_pressed)
	
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

# Private methods
func _update_resources_display():
	"""Updates the gold and essence displays"""
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return
	
	if _gold_label:
		_gold_label.text = str(game_manager.player_gold)
	
	if _essence_label:
		_essence_label.text = str(game_manager.player_essence)

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
			button.pressed = false
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
		active_button.pressed = true
		active_button.modulate = Color(1, 1, 1)  # Full brightness

func _update_all_displays():
	"""Updates all UI displays"""
	_update_resources_display()
	_update_level_display()
	_update_active_scene_button()

func _on_inventory_button_pressed():
	"""Toggles the inventory panel"""
	if _inventory_panel:
		_inventory_panel.visible = !_inventory_panel.visible
		if _inventory_panel.visible and _recipe_book and _recipe_book.visible:
			_recipe_book.visible = false

func _on_workshop_button_pressed():
	"""Switches to workshop scene"""
	if _current_scene != "workshop":
		emit_signal("scene_change_requested", "workshop")

func _on_garden_button_pressed():
	"""Switches to garden scene"""
	if _current_scene != "garden":
		emit_signal("scene_change_requested", "garden")

func _on_forest_button_pressed():
	"""Switches to forest scene"""
	if _current_scene != "forest_edge":
		emit_signal("scene_change_requested", "forest_edge")
