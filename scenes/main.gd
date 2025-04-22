extends Node
## Main game scene controller

# Node references
@onready var _workshop_scene = $Workshop
@onready var _gathering_scene = $GatheringAreas
@onready var _ui_layer = $UILayer
@onready var _hud = $UILayer/HUD
@onready var _transition_animator = $TransitionAnimator
@onready var _transition_rect = $UILayer/TransitionRect

# Private variables
var _current_scene = "workshop"  # Current active scene
var _scenes = {
	"workshop": null,
	"garden": null,
	"forest_edge": null
}
var _is_transitioning = false

# Lifecycle methods
func _ready():
	# Make sure transition rect is invisible at start
	if _transition_rect:
		_transition_rect.modulate.a = 0
	
	# Store scene references
	_scenes.workshop = $Workshop
	_scenes.garden = $GatheringAreas/Garden
	_scenes.forest_edge = $GatheringAreas/ForestEdge
	
	# Connect HUD navigation buttons
	_connect_navigation_buttons()
	
	# Set up initial scene
	_update_visible_scene(_current_scene)
	
	# Initialize gathering areas with resource spawn points
	_initialize_gathering_areas()
	
	# Connect to GameManager signals
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.game_initialized.connect(_on_game_initialized)
		game_manager.game_loaded.connect(_on_game_loaded)

# Public methods
func get_current_scene() -> String:
	"""Returns the name of the currently active scene"""
	return _current_scene

# Private methods
func _connect_navigation_buttons():
	"""Connect HUD navigation buttons if they exist"""
	if _hud:
		var workshop_button = _hud.get_node_or_null("BottomBar/NavButtons/WorkshopButton")
		var garden_button = _hud.get_node_or_null("BottomBar/NavButtons/GardenButton")
		var forest_button = _hud.get_node_or_null("BottomBar/NavButtons/ForestButton")
		
		if workshop_button:
			workshop_button.pressed.connect(func(): _change_scene("workshop"))
		
		if garden_button:
			garden_button.pressed.connect(func(): _change_scene("garden"))
		
		if forest_button:
			forest_button.pressed.connect(func(): _change_scene("forest_edge"))
		
		# Also connect to the scene_change_requested signal if it exists
		if _hud.has_signal("scene_change_requested"):
			_hud.scene_change_requested.connect(_change_scene)

func _change_scene(scene_name: String) -> void:
	"""Changes to the specified game scene"""
	if _is_transitioning or not _scenes.has(scene_name) or _current_scene == scene_name:
		return
	
	_is_transitioning = true
	
	# Play transition animation if available
	if _transition_animator and _transition_animator.has_animation("fade_out"):
		_transition_animator.play("fade_out")
		await _transition_animator.animation_finished
		
		# Change the scene
		_update_visible_scene(scene_name)
		
		# Play fade in animation
		_transition_animator.play("fade_in")
		await _transition_animator.animation_finished
	else:
		# No animator, just change the scene
		_update_visible_scene(scene_name)
	
	_is_transitioning = false

func _update_visible_scene(scene_name: String) -> void:
	"""Updates which scene is currently visible"""
	# Hide all scenes
	for key in _scenes:
		if _scenes[key]:
			_scenes[key].visible = false
	
	# Show the requested scene
	if _scenes.has(scene_name) and _scenes[scene_name]:
		_scenes[scene_name].visible = true
		_current_scene = scene_name
	
	# Update HUD to reflect current scene
	if _hud and _hud.has_method("update_current_scene"):
		_hud.update_current_scene(scene_name)
	
	# Emit a signal to the scene being entered
	if scene_name == "garden" and _scenes.garden:
		if _scenes.garden.has_method("emit_signal") and _scenes.garden.has_signal("area_entered"):
			_scenes.garden.emit_signal("area_entered")
	elif scene_name == "forest_edge" and _scenes.forest_edge:
		if _scenes.forest_edge.has_method("emit_signal") and _scenes.forest_edge.has_signal("area_entered"):
			_scenes.forest_edge.emit_signal("area_entered")

func _initialize_gathering_areas() -> void:
	"""Sets up gathering areas with resource spawn points"""
	var gathering_system = get_node_or_null("/root/GatheringSystem")
	if not gathering_system:
		return
	
	# Garden area
	var garden_positions = []
	if _scenes.garden:
		# Get spawn positions from children named SpawnPoint
		for child in _scenes.garden.get_children():
			if child.name.begins_with("SpawnPoint") and child is Marker2D:
				garden_positions.append(child.global_position)
		
		# Initialize garden with spawn points
		gathering_system.initialize_gathering_area(
			"garden", 
			garden_positions, 
			["ing_lavender", "ing_sage", "ing_mint", "ing_chamomile"]  # Initial resources
		)
	
	# Forest edge area
	var forest_positions = []
	if _scenes.forest_edge:
		# Get spawn positions from children named SpawnPoint
		for child in _scenes.forest_edge.get_children():
			if child.name.begins_with("SpawnPoint") and child is Marker2D:
				forest_positions.append(child.global_position)
		
		# Initialize forest with spawn points
		gathering_system.initialize_gathering_area(
			"forest_edge", 
			forest_positions, 
			["ing_mushrooms", "ing_clay"]  # Initial resources
		)
	
	# Notify with successful initialization
	var notification_system = get_node_or_null("/root/NotificationSystem")
	if notification_system:
		notification_system.show_info("Game world initialized")

func _on_game_initialized() -> void:
	"""Called when a new game is started"""
	# Reset to workshop scene
	_change_scene("workshop")
	
	# Refresh all systems
	var gathering_system = get_node_or_null("/root/GatheringSystem")
	if gathering_system:
		gathering_system.refresh_daily_resources()
	
	# Welcome notification
	var notification_system = get_node_or_null("/root/NotificationSystem")
	if notification_system:
		notification_system.show_success("Welcome to your Alchemy Workshop!")

func _on_game_loaded() -> void:
	"""Called when a game is loaded"""
	# Similar to game initialized, but might have different logic
	_on_game_initialized()
	
	# Welcome back notification
	var notification_system = get_node_or_null("/root/NotificationSystem")
	if notification_system:
		notification_system.show_success("Welcome back to your workshop!")
