extends Node
## Handles resource gathering mechanics and node spawning
## Add this script to an autoload in the Project Settings

# Signals
signal resource_spawned(resource_id, node_id)
signal resource_gathered(resource_id, quantity, quality)
signal resource_regeneration_started(resource_id, time_remaining)
signal resource_regeneration_complete(resource_id, node_id)

# Constants
const BASE_GATHERING_QUANTITY = 1
const QUALITY_VARIATION = 0.2  # +/- 20% quality variation

# Resources
const RESOURCE_NODE_SCENE = preload("res://scenes/gathering/resource_node.tscn")

# Private variables
var _active_nodes = {}  # node_id: {resource_id, time_remaining, timer}
var _regenerating_resources = {}  # resource_id: {time_remaining, node_id, timer}
var _spawn_locations = {}  # location_id: [position Vector2s]
var _current_season = "spring"
var _current_weather = "clear"
var _gathering_skill_level = 1
var _gathering_luck = 1.0

# Lifecycle methods
func _ready():
	# Register with GameManager
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").gathering_system = self

# Public methods
func initialize_gathering_area(area_id, spawn_positions, initial_resources=[]):
	"""Sets up a gathering area with resource spawn points"""
	_spawn_locations[area_id] = spawn_positions
	
	# Spawn initial resources if provided
	for resource_id in initial_resources:
		spawn_resource(resource_id, area_id)

func spawn_resource(resource_id, area_id):
	"""
	Spawns a resource node in the given area
	Returns the unique node_id if successful, or empty string if failed
	"""
	# Ensure we have spawn locations for this area
	if not _spawn_locations.has(area_id) or _spawn_locations[area_id].empty():
		return ""
	
	# Get a random spawn position
	var spawn_index = randi() % _spawn_locations[area_id].size()
	var spawn_position = _spawn_locations[area_id][spawn_index]
	
	# Check if we can spawn the resource (availability, season, etc.)
	if not _can_spawn_resource(resource_id):
		return ""
	
	# Generate unique node ID
	var node_id = resource_id + "_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())
	
	# Create resource node instance
	var resource_node_instance = RESOURCE_NODE_SCENE.instantiate()
	resource_node_instance.position = spawn_position
	resource_node_instance.resource_id = resource_id
	resource_node_instance.node_id = node_id
	
	# Connect signals
	resource_node_instance.resource_gathered.connect(_on_resource_gathered)
	
	# Store in active nodes
	_active_nodes[node_id] = {
		"resource_id": resource_id,
		"area_id": area_id,
		"position": spawn_position
	}
	
	# Get the gathering area node
	var gathering_area = _get_gathering_area(area_id)
	if gathering_area:
		gathering_area.add_child(resource_node_instance)
	
	resource_spawned.emit(resource_id, node_id)
	return node_id

func gather_resource(node_id):
	"""
	Attempts to gather from a resource node
	Returns a dictionary with success status and gather results
	"""
	# Check if the node exists
	if not _active_nodes.has(node_id):
		return {"success": false, "error": "Node not found"}
	
	var node_data = _active_nodes[node_id]
	var resource_id = node_data.resource_id
	
	# Calculate gathering quantities and quality
	var quantity = _calculate_gathering_quantity(resource_id)
	var quality = _calculate_gathering_quality(resource_id)
	
	# Remove the node
	_remove_resource_node(node_id)
	
	# Start regeneration timer
	_start_regeneration_timer(resource_id, node_id, node_data.area_id, node_data.position)
	
	# Signal the gather
	resource_gathered.emit(resource_id, quantity, quality)
	
	return {
		"success": true,
		"resource_id": resource_id,
		"quantity": quantity,
		"quality": quality
	}

func set_current_season(season):
	"""Sets the current season, affecting resource availability"""
	_current_season = season
	# Potentially refresh resources based on new season
	_refresh_seasonal_resources()

func set_current_weather(weather):
	"""Sets the current weather, affecting resource spawning"""
	_current_weather = weather
	# Potentially adjust active resources based on weather
	_refresh_weather_dependent_resources()

func set_gathering_skill(level):
	"""Sets the player's gathering skill level"""
	_gathering_skill_level = level

func set_gathering_luck(luck_value):
	"""Sets the player's gathering luck modifier"""
	_gathering_luck = luck_value

func refresh_daily_resources():
	"""Refreshes resources that change on a daily basis"""
	# Potentially change weather
	_roll_daily_weather()
	
	# Refresh any daily-specific resources
	for area_id in _spawn_locations.keys():
		_spawn_daily_resources(area_id)

func get_regeneration_time(resource_id):
	"""Gets the current regeneration time for a resource type"""
	var base_time = _get_resource_regen_time(resource_id)
	var skill_modifier = max(0.5, 1.0 - ((_gathering_skill_level - 1) * 0.05))
	
	return base_time * skill_modifier

func get_active_node_ids():
	"""Returns a list of all active resource node IDs"""
	return _active_nodes.keys()

func get_regenerating_resources():
	"""Returns a dictionary of resources currently regenerating"""
	return _regenerating_resources.duplicate()

# Private methods
func _calculate_gathering_quantity(resource_id):
	"""Calculates how much of the resource is gathered"""
	var base_quantity = BASE_GATHERING_QUANTITY
	
	# Skill bonuses increase quantity
	var skill_bonus = floor(_gathering_skill_level / 5)  # +1 every 5 levels
	
	# Luck can give bonus drops
	var luck_bonus = 0
	if randf() < (_gathering_luck * 0.1):  # 10% chance at base luck
		luck_bonus = 1
	
	return base_quantity + skill_bonus + luck_bonus

func _calculate_gathering_quality(resource_id):
	"""Calculates the quality of the gathered resource"""
	var base_quality = 1.0
	
	# Skill affects base quality
	var skill_modifier = 1.0 + ((_gathering_skill_level - 1) * 0.02)  # +2% per level
	
	# Random variation
	var random_variation = randf_range(-QUALITY_VARIATION, QUALITY_VARIATION)
	
	# Calculate final quality with limits
	var final_quality = base_quality * skill_modifier * (1.0 + random_variation)
	final_quality = clamp(final_quality, 0.5, 2.0)  # Quality between 50% and 200%
	
	return final_quality

func _can_spawn_resource(resource_id):
	"""Checks if a resource can be spawned based on current conditions"""
	# Get ingredient data
	var ingredient_data = _get_ingredient_data(resource_id)
	if not ingredient_data:
		return false
	
	# Check if seasonal and whether it's the right season
	if ingredient_data.seasonal and ingredient_data.season != _current_season:
		return false
	
	# Check weather requirements if any
	var weather_requirements = ingredient_data.get("weather_requirements", [])
	if not weather_requirements.empty() and not _current_weather in weather_requirements:
		return false
	
	# Time-of-day requirements could be added here
	
	return true

func _start_regeneration_timer(resource_id, node_id, area_id, position):
	"""Starts a timer for resource regeneration"""
	var regen_time = get_regeneration_time(resource_id)
	
	# Create a timer
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = regen_time
	add_child(timer)
	
	# Connect timeout signal
	timer.timeout.connect(_on_regeneration_complete.bind(resource_id, area_id, position, timer))
	
	# Store regeneration data
	_regenerating_resources[resource_id] = {
		"time_remaining": regen_time,
		"total_time": regen_time,
		"area_id": area_id,
		"position": position,
		"timer": timer
	}
	
	# Start the timer
	timer.start()
	
	resource_regeneration_started.emit(resource_id, regen_time)

func _on_regeneration_complete(resource_id, area_id, position, timer):
	"""Called when a resource has finished regenerating"""
	# Remove from regenerating list
	if _regenerating_resources.has(resource_id):
		_regenerating_resources.erase(resource_id)
	
	# Clean up timer
	timer.queue_free()
	
	# Spawn new resource
	var new_node_id = spawn_resource(resource_id, area_id)
	
	resource_regeneration_complete.emit(resource_id, new_node_id)

func _on_resource_gathered(node_id):
	"""Called when a resource is gathered by player interaction"""
	gather_resource(node_id)

func _remove_resource_node(node_id):
	"""Removes a resource node from the game"""
	if not _active_nodes.has(node_id):
		return
	
	var node_data = _active_nodes[node_id]
	var area_id = node_data.area_id
	
	# Find the actual node instance
	var gathering_area = _get_gathering_area(area_id)
	if gathering_area:
		for child in gathering_area.get_children():
			if child.has_method("get_node_id") and child.get_node_id() == node_id:
				child.queue_free()
				break
	
	# Remove from active nodes list
	_active_nodes.erase(node_id)

func _get_gathering_area(area_id):
	"""Returns the gathering area node with the given ID"""
	# This would need to be adjusted based on your scene structure
	var base_path = "/root/Main/GatheringAreas/"
	var area_path = base_path + area_id
	
	if has_node(area_path):
		return get_node(area_path)
	
	return null

func _get_ingredient_data(resource_id):
	"""Gets ingredient data for the given resource ID"""
	if has_node("/root/IngredientManager"):
		return get_node("/root/IngredientManager").get_ingredient(resource_id)
	return null

func _get_resource_regen_time(resource_id):
	"""Gets the base regeneration time for a resource"""
	var ingredient_data = _get_ingredient_data(resource_id)
	if ingredient_data:
		return ingredient_data.regeneration_time
	return 120.0  # Default: 2 minutes

func _roll_daily_weather():
	"""Randomly changes the weather based on the current season"""
	var weather_options = {
		"spring": ["clear", "rainy", "foggy"],
		"summer": ["clear", "hot", "stormy"],
		"autumn": ["clear", "windy", "rainy"],
		"winter": ["clear", "snowy", "freezing"]
	}
	
	var options = weather_options.get(_current_season, ["clear"])
	var random_index = randi() % options.size()
	
	set_current_weather(options[random_index])

func _spawn_daily_resources(area_id):
	"""Spawns daily-specific resources in the given area"""
	# This would be implemented based on your specific resource system
	# For example, rare resources that only spawn once per day
	pass

func _refresh_seasonal_resources():
	"""Updates resources based on season changes"""
	# Remove out-of-season resources
	var nodes_to_remove = []
	for node_id in _active_nodes.keys():
		var resource_id = _active_nodes[node_id].resource_id
		var ingredient_data = _get_ingredient_data(resource_id)
		
		if ingredient_data and ingredient_data.seasonal and ingredient_data.season != _current_season:
			nodes_to_remove.append(node_id)
	
	for node_id in nodes_to_remove:
		_remove_resource_node(node_id)
	
	# Spawn new seasonal resources in each area
	for area_id in _spawn_locations.keys():
		_spawn_seasonal_resources(area_id)

func _refresh_weather_dependent_resources():
	"""Updates resources based on weather changes"""
	# Similar to seasonal resources but for weather-dependent ones
	pass

func _spawn_seasonal_resources(area_id):
	"""Spawns season-specific resources in the given area"""
	# This would be implemented based on your specific resource system
	pass
