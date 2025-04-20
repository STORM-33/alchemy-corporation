extends Resource
class_name Ingredient
## Resource class for storing ingredient data

# Properties
@export var id: String = ""  # Unique identifier
@export var name: String = ""  # Display name
@export var description: String = ""  # Description text
@export var category: String = "common_plants"  # Ingredient category
@export var base_value: int = 1  # Base gold value
@export var rarity: int = 1  # 1 (common) to 5 (legendary)
@export var regeneration_time: float = 120.0  # Time in seconds to regenerate
@export var properties: Dictionary = {}  # Properties like "healing", "binding", etc.
@export var gathering_requirements: Array = []  # Special requirements to gather
@export var seasonal: bool = false  # Whether this is a seasonal ingredient
@export var season: String = ""  # If seasonal, which season it appears in

# Methods
func _init(p_id="", p_name="", p_description="", p_category="common_plants", 
		   p_base_value=1, p_rarity=1, p_regen_time=120.0, p_properties={}):
	id = p_id
	name = p_name
	description = p_description
	category = p_category
	base_value = p_base_value
	rarity = p_rarity
	regeneration_time = p_regen_time
	properties = p_properties

func get_icon_path() -> String:
	"""Returns the path to this ingredient's icon"""
	return "res://assets/images/ingredients/%s/%s.png" % [category, id]

func get_adjusted_value(quality=1.0) -> int:
	"""Returns the adjusted value based on quality and rarity"""
	return int(base_value * quality * rarity)

func has_property(property_name: String) -> bool:
	"""Checks if the ingredient has the given property"""
	return property_name in properties

func get_property_strength(property_name: String) -> float:
	"""Gets the strength of a specific property"""
	if property_name in properties:
		return properties[property_name]
	return 0

func to_dict() -> Dictionary:
	"""Convert ingredient to dictionary for saving"""
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

func from_dict(data: Dictionary) -> Ingredient:
	"""Load ingredient from dictionary data"""
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	category = data.get("category", "common_plants")
	base_value = data.get("base_value", 1)
	rarity = data.get("rarity", 1)
	regeneration_time = data.get("regeneration_time", 120.0)
	properties = data.get("properties", {})
	gathering_requirements = data.get("gathering_requirements", [])
	seasonal = data.get("seasonal", false)
	season = data.get("season", "")
	return self

func _to_string() -> String:
	"""Returns a string representation of the ingredient for debugging"""
	return "%s (Rarity: %d, Value: %d)" % [name, rarity, base_value]
