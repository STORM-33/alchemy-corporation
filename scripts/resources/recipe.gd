extends Resource
class_name Recipe
## Resource class for storing potion recipe data

# Properties
@export var id: String = ""  # Unique identifier
@export var name: String = ""  # Display name
@export var description: String = ""  # Description text
@export var category: String = "healing"  # Recipe category
@export var ingredients: Array = []  # Required ingredient IDs
@export var result_id: String = ""  # ID of produced potion
@export var difficulty: int = 1  # 1 (easy) to 5 (very hard)
@export var discovered: bool = false  # Whether player has discovered this recipe
@export var properties: Dictionary = {}  # Properties like "healing", "duration", etc.
@export var requirements: Dictionary = {}  # Special requirements like station level
@export var experimental: bool = false  # Whether this is a discovered experimental recipe

# Methods
func _init(p_id="", p_name="", p_description="", p_category="healing",
		   p_ingredients=[], p_result_id="", p_difficulty=1):
	id = p_id
	name = p_name
	description = p_description
	category = p_category
	ingredients = p_ingredients
	result_id = p_result_id
	difficulty = p_difficulty

func get_icon_path() -> String:
	"""Returns the path to this recipe's result icon"""
	return "res://assets/images/potions/%s/%s.png" % [category, result_id]

func matches_ingredients(ingredient_list: Array) -> float:
	"""
	Checks if the given ingredient list matches this recipe
	Returns match percentage (1.0 = perfect match)
	"""
	# If lengths don't match, immediate fail
	if ingredient_list.size() != ingredients.size():
		return 0.0
	
	# Check each ingredient
	var required_ingredients = ingredients.duplicate()
	var matches = 0
	
	for ing in ingredient_list:
		var index = required_ingredients.find(ing)
		if index != -1:
			matches += 1
			required_ingredients.remove_at(index)  # Changed from remove() to remove_at()
	
	# Calculate match percentage
	return float(matches) / ingredients.size()

func meets_requirements(station_level: int, specialization_levels: Dictionary) -> bool:
	"""Checks if all requirements for brewing are met"""
	# Check station level
	if requirements.has("station_level") and station_level < requirements.station_level:
		return false
	
	# Check specialization
	if requirements.has("specialization"):
		var spec_name = requirements.specialization.name
		var spec_level = requirements.specialization.level
		
		if not specialization_levels.has(spec_name) or specialization_levels[spec_name] < spec_level:
			return false
	
	return true

func to_dict() -> Dictionary:
	"""Convert recipe to dictionary for saving"""
	return {
		"id": id,
		"name": name,
		"description": description,
		"category": category,
		"ingredients": ingredients,
		"result_id": result_id,
		"difficulty": difficulty,
		"discovered": discovered,
		"properties": properties,
		"requirements": requirements,
		"experimental": experimental
	}

func from_dict(data: Dictionary) -> Recipe:
	"""Load recipe from dictionary data"""
	id = data.get("id", "")
	name = data.get("name", "")
	description = data.get("description", "")
	category = data.get("category", "healing")
	
	# Handle array conversion correctly for Godot 4
	if data.has("ingredients"):
		ingredients.clear()
		for ing in data.get("ingredients", []):
			ingredients.append(ing)
	
	result_id = data.get("result_id", "")
	difficulty = data.get("difficulty", 1)
	discovered = data.get("discovered", false)
	properties = data.get("properties", {})
	requirements = data.get("requirements", {})
	experimental = data.get("experimental", false)
	return self

func _to_string() -> String:
	"""Returns a string representation of the recipe for debugging"""
	return "%s (Difficulty: %d, Ingredients: %d)" % [name, difficulty, ingredients.size()]
