extends Resource
## Resource class for recipe definitions
## A recipe defines how to create a specific potion

class_name Recipe

# Properties
@export var id: String
@export var name: String
@export var description: String
@export var category: String
@export var ingredients: Array
@export var result_id: String
@export var difficulty: int = 1
@export var discovered: bool = false
@export var properties: Dictionary = {}
@export var requirements: Dictionary = {}
@export var experimental: bool = false

# Constructor
func _init(p_id="", p_name="", p_description="", p_category="", p_ingredients=[], p_result_id="", p_difficulty=1, p_discovered=false):
	id = p_id
	name = p_name
	description = p_description
	category = p_category
	ingredients = p_ingredients
	result_id = p_result_id
	difficulty = p_difficulty
	discovered = p_discovered

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
	if data.has("ingredients"):
		ingredients = data.ingredients
	if data.has("result_id"):
		result_id = data.result_id
	if data.has("difficulty"):
		difficulty = data.difficulty
	if data.has("discovered"):
		discovered = data.discovered
	if data.has("properties"):
		properties = data.properties
	if data.has("requirements"):
		requirements = data.requirements
	if data.has("experimental"):
		experimental = data.experimental
	
	return self

# Convert to dictionary
func to_dict():
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

# Check if player meets requirements to brew this recipe
func can_brew(station_levels, specializations):
	# Check station level requirement
	if requirements.has("station_level") and station_levels.has(category):
		if station_levels[category] < requirements.station_level:
			return false
	
	# Check specialization requirement
	if requirements.has("specialization") and specializations.has(category):
		if specializations[category] < requirements.specialization:
			return false
	
	return true
