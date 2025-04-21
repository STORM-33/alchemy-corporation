extends Resource
## Resource class for ingredient definitions
## Ingredients are the building blocks for brewing potions

class_name Ingredient

# Properties
@export var id: String
@export var name: String
@export var description: String
@export var category: String
@export var base_value: int = 1
@export var rarity: int = 1
@export var regeneration_time: float = 120.0
@export var properties: Dictionary = {}
@export var gathering_requirements: Array = []
@export var seasonal: bool = false
@export var season: String = ""

# Constructor
func _init(p_id="", p_name="", p_description="", p_category="", p_value=1, p_rarity=1, p_regen_time=120.0, p_properties={}):
	id = p_id
	name = p_name
	description = p_description
	category = p_category
	base_value = p_value
	rarity = p_rarity
	regeneration_time = p_regen_time
	properties = p_properties

# Load from dictionary
func from_dict(data):
	if data.has("id"):
		id = data.id
	if data.has("name"):
		name = data.name
	if data.has("description"):
		description = data.description
	if data.has("category"):
		category = data.category
	if data.has("base_value"):
		base_value = data.base_value
	if data.has("rarity"):
		rarity = data.rarity
	if data.has("regeneration_time"):
		regeneration_time = data.regeneration_time
	if data.has("properties"):
		properties = data.properties
	if data.has("gathering_requirements"):
		gathering_requirements = data.gathering_requirements
	if data.has("seasonal"):
		seasonal = data.seasonal
	if data.has("season"):
		season = data.season
	
	return self

# Convert to dictionary
func to_dict():
	return {
		"id": id,
		"name": name,
		"description": description,
		"category": category,
		"base_value": base_value,
		"rarity": rarity,
		"regeneration_time": regeneration_time,
		"properties": properties,
		"gathering_requirements": gathering_requirements,
		"seasonal": seasonal,
		"season": season
	}

# Get the path to the ingredient's icon
func get_icon_path() -> String:
	return "res://assets/images/ingredients/%s/%s.png" % [category, id]

# Calculate sell value (potentially affected by quality)
func get_sell_value(quality = 1.0) -> int:
	return int(base_value * quality)

# Check if ingredient meets gathering requirements
func can_gather(player_stats, current_time, current_weather) -> bool:
	for requirement in gathering_requirements:
		match requirement:
			"dawn_only":
				# Check if it's dawn (6am-8am)
				var hour = current_time.hour
				if hour < 6 or hour > 8:
					return false
			"night_only":
				# Check if it's night (8pm-5am)
				var hour = current_time.hour
				if hour > 5 and hour < 20:
					return false
			"special_tool":
				# Check if player has the required tool
				if not player_stats.has_tool(id.replace("ing_", "tool_")):
					return false
	
	# Check if seasonal and whether it's the right season
	if seasonal and season != current_weather.season:
		return false
	
	return true
