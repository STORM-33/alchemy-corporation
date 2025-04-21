extends Node2D
## Main workshop scene where potion brewing occurs

# Signals
signal station_selected(station_name)
signal brewing_started(recipe_name)
signal brewing_completed(potion_name, quality)

# Onready variables
@onready var _cauldron = $Stations/Cauldron
@onready var _distillery = $Stations/Distillery
@onready var _herb_station = $Stations/HerbStation
@onready var _study_table = $Stations/StudyTable

@onready var _cauldron_area = $InteractionAreas/CauldronArea
@onready var _distillery_area = $InteractionAreas/DistilleryArea
@onready var _herb_area = $InteractionAreas/HerbArea
@onready var _study_area = $InteractionAreas/StudyArea

# Private variables
var _current_station = ""
var _unlocked_stations = []

# Lifecycle methods
func _ready():
	# Connect interaction areas - using Godot 4 signal connection
	if _cauldron_area:
		_cauldron_area.input_event.connect(_on_station_input.bind("cauldron"))
	if _distillery_area:
		_distillery_area.input_event.connect(_on_station_input.bind("distillery"))
	if _herb_area:
		_herb_area.input_event.connect(_on_station_input.bind("herb_station"))
	if _study_area:
		_study_area.input_event.connect(_on_station_input.bind("study_table"))
	
	# Get unlocked stations from GameManager
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		_unlocked_stations = game_manager.unlocked_stations
	else:
		# Default for testing
		_unlocked_stations = ["cauldron"]
	
	# Setup stations based on unlocked status
	_update_station_visibility()
	
	# Connect station signals
	if _cauldron:
		_cauldron.brewing_started.connect(_on_brewing_started)
		_cauldron.brewing_completed.connect(_on_brewing_completed)
	
	# Default to cauldron as starting station
	if "cauldron" in _unlocked_stations:
		select_station("cauldron")

# Public methods
func select_station(station_name):
	"""Selects a specific station as active"""
	if station_name in _unlocked_stations:
		_current_station = station_name
		station_selected.emit(station_name)
		
		# Highlight the selected station
		_highlight_station(station_name)
		
		return true
	
	return false

func start_brewing(recipe_id, ingredients):
	"""Attempts to start brewing using the current station"""
	if _current_station == "":
		return {"success": false, "error": "No station selected"}
	
	var station_node = _get_station_node(_current_station)
	if not station_node or not station_node.has_method("brew_potion"):
		return {"success": false, "error": "Invalid station"}
	
	var result = station_node.brew_potion(recipe_id, ingredients)
	
	if result.success:
		brewing_started.emit(result.recipe_name)
	
	return result

func get_unlocked_stations():
	"""Returns a list of currently unlocked stations"""
	return _unlocked_stations.duplicate()

func unlock_station(station_name):
	"""Unlocks a new station"""
	if station_name in _unlocked_stations:
		return false
	
	_unlocked_stations.append(station_name)
	_update_station_visibility()
	
	# Notify the player
	var notification_system = get_node_or_null("/root/NotificationSystem")
	if notification_system:
		notification_system.show_success("Unlocked new station: " + station_name.capitalize())
	
	return true

# Private methods
func _on_station_input(_viewport, event, _shape_idx, station_name):
	"""Handles input on station interaction areas"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select_station(station_name)

func _update_station_visibility():
	"""Updates station visibility based on unlock status"""
	# Cauldron is always visible (first station)
	if _cauldron:
		_cauldron.visible = true
	
	# Other stations depend on unlock status
	if _distillery:
		_distillery.visible = "distillery" in _unlocked_stations
	
	if _herb_station:
		_herb_station.visible = "herb_station" in _unlocked_stations
	
	if _study_table:
		_study_table.visible = "study_table" in _unlocked_stations
	
	# Update interaction areas
	if _distillery_area:
		_distillery_area.monitoring = "distillery" in _unlocked_stations
		_distillery_area.monitorable = "distillery" in _unlocked_stations
	
	if _herb_area:
		_herb_area.monitoring = "herb_station" in _unlocked_stations
		_herb_area.monitorable = "herb_station" in _unlocked_stations
	
	if _study_area:
		_study_area.monitoring = "study_table" in _unlocked_stations
		_study_area.monitorable = "study_table" in _unlocked_stations

func _highlight_station(station_name):
	"""Highlights the selected station and dims others"""
	var stations = {
		"cauldron": _cauldron,
		"distillery": _distillery,
		"herb_station": _herb_station,
		"study_table": _study_table
	}
	
	# Reset all stations
	for name in stations:
		if stations[name]:
			stations[name].modulate = Color(0.8, 0.8, 0.8, 1.0)
	
	# Highlight selected station
	if station_name in stations and stations[station_name]:
		stations[station_name].modulate = Color(1.0, 1.0, 1.0, 1.0)

func _get_station_node(station_name):
	"""Returns the node for the specified station"""
	match station_name:
		"cauldron":
			return _cauldron
		"distillery":
			return _distillery
		"herb_station":
			return _herb_station
		"study_table":
			return _study_table
	
	return null

func _on_brewing_started(recipe_id):
	"""Handle brewing start from any station"""
	var recipe_manager = get_node_or_null("/root/RecipeManager")
	var recipe_name = "Unknown Recipe"
	
	if recipe_manager and recipe_id != "":
		var recipe = recipe_manager.get_recipe(recipe_id)
		if recipe:
			recipe_name = recipe.name
	
	# Show notification
	var notification_system = get_node_or_null("/root/NotificationSystem")
	if notification_system:
		notification_system.show_info("Brewing " + recipe_name + "...")
	
	brewing_started.emit(recipe_name)

func _on_brewing_completed(potion_id, potion_name, quality):
	"""Handle brewing completion from any station"""
	# Format quality as percentage
	var quality_percent = int(quality * 100)
	var quality_text = ""
	
	if quality >= 1.5:
		quality_text = "Excellent quality (" + str(quality_percent) + "%)"
	elif quality >= 1.0:
		quality_text = "Good quality (" + str(quality_percent) + "%)"
	else:
		quality_text = "Poor quality (" + str(quality_percent) + "%)"
	
	# Show notification
	var notification_system = get_node_or_null("/root/NotificationSystem")
	if notification_system:
		notification_system.show_success("Created " + potion_name + "\n" + quality_text)
	
	brewing_completed.emit(potion_name, quality)
