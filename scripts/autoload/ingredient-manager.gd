extends Node
## Manages all ingredient data and definitions
## Add this script to an autoload in the Project Settings

# Signals
signal ingredients_loaded()
signal ingredient_added(ingredient_id)

# Private variables
var _ingredients = {}  # Dictionary of ingredient_id: Ingredient resource
var _ingredients_by_category = {}  # Dictionary of category: [ingredient_ids]

# Lifecycle methods
func _ready():
	# Load all ingredient data
	_load_ingredients()

# Public methods
func get_ingredient(ingredient_id):
	"""Returns the ingredient with the given ID or null if not found"""
	if _ingredients.has(ingredient_id):
		return _ingredients[ingredient_id]
	return null

func get_ingredients_by_category(category):
	"""Returns a list of ingredient IDs in the given category"""
	if _ingredients_by_category.has(category):
		return _ingredients_by_category[category].duplicate()
	return []

func get_all_ingredient_ids():
	"""Returns a list of all ingredient IDs"""
	return _ingredients.keys()

func get_all_categories():
	"""Returns a list of all ingredient categories"""
	return _ingredients_by_category.keys()

func add_ingredient(ingredient):
	"""Adds a new ingredient definition"""
	if not ingredient or not ingredient is Ingredient:
		return false
	
	var ingredient_id = ingredient.id
	
	# Add to ingredients dictionary
	_ingredients[ingredient_id] = ingredient
	
	# Add to category list
	var category = ingredient.category
	if not _ingredients_by_category.has(category):
		_ingredients_by_category[category] = []
	
	if not ingredient_id in _ingredients_by_category[category]:
		_ingredients_by_category[category].append(ingredient_id)
	
	ingredient_added.emit(ingredient_id)
	return true

func create_ingredient(id, name, description, category, base_value, rarity, regen_time, properties):
	"""Creates and adds a new ingredient with the given parameters"""
	var ingredient = Ingredient.new(
		id, name, description, category, 
		base_value, rarity, regen_time, properties
	)
	
	return add_ingredient(ingredient)

# Private methods
func _load_ingredients():
	"""Loads all ingredient definitions"""
	# Clear existing data
	_ingredients.clear()
	_ingredients_by_category.clear()
	
	# Setup basic categories
	_ingredients_by_category = {
		"common_plants": [],
		"mineral_elements": [],
		"animal_products": [],
		"special_elements": []
	}
	
	# Load from data file if it exists
	var file_path = "res://data/ingredients.json"
	
	if FileAccess.file_exists(file_path):
		# Load from JSON file
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var json_result = json.parse(json_text)
		if json_result == OK:
			var ingredients_data = json.data
			
			# Create ingredients from data
			for ingredient_data in ingredients_data:
				var ingredient = Ingredient.new()
				ingredient.from_dict(ingredient_data)
				add_ingredient(ingredient)
		else:
			push_error("Failed to parse ingredients JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
			# Fall back to hardcoded ingredients
			_create_default_ingredients()
	else:
		# Fall back to hardcoded ingredients
		_create_default_ingredients()
	
	ingredients_loaded.emit()

func _create_default_ingredients():
	"""Creates default ingredient definitions if data file is missing"""
	# Common Plants
	create_ingredient(
		"ing_lavender",
		"Lavender",
		"A fragrant purple flower with calming properties.",
		"common_plants",
		2,  # Base value
		1,  # Rarity (1-5)
		120.0,  # Regeneration time in seconds (2 min)
		{"calming": 1.0, "aromatic": 0.8}  # Properties
	)
	
	create_ingredient(
		"ing_sage",
		"Sage",
		"A culinary and medicinal herb with clarity properties.",
		"common_plants",
		3,
		1,
		180.0,  # 3 min
		{"clarity": 1.0, "purifying": 0.7}
	)
	
	create_ingredient(
		"ing_mint",
		"Mint",
		"A refreshing herb with energy-boosting properties.",
		"common_plants",
		2,
		1,
		120.0,  # 2 min
		{"energy": 1.0, "cooling": 0.9}
	)
	
	create_ingredient(
		"ing_mushrooms",
		"Mushrooms",
		"Forest fungi with transformative properties.",
		"common_plants",
		4,
		2,
		300.0,  # 5 min
		{"transformation": 1.0, "growth": 0.6}
	)
	
	create_ingredient(
		"ing_chamomile",
		"Chamomile",
		"Daisy-like flowers with healing and soothing properties.",
		"common_plants",
		3,
		1,
		240.0,  # 4 min
		{"healing": 1.0, "soothing": 0.8}
	)
	
	# Mineral Elements
	create_ingredient(
		"ing_quartz_dust",
		"Quartz Dust",
		"Powdered crystal with focus-enhancing properties.",
		"mineral_elements",
		5,
		2,
		420.0,  # 7 min
		{"focus": 1.0, "clarity": 0.5}
	)
	
	create_ingredient(
		"ing_iron_filings",
		"Iron Filings",
		"Tiny pieces of iron with strengthening properties.",
		"mineral_elements",
		6,
		2,
		600.0,  # 10 min
		{"strength": 1.0, "durability": 0.7}
	)
	
	create_ingredient(
		"ing_clay",
		"Clay",
		"Malleable earth with stabilizing properties.",
		"mineral_elements",
		3,
		1,
		300.0,  # 5 min
		{"stability": 1.0, "binding": 0.6}
	)
	
	create_ingredient(
		"ing_salt",
		"Salt",
		"Crystalline mineral with preservation properties.",
		"mineral_elements",
		4,
		1,
		480.0,  # 8 min
		{"preservation": 1.0, "purifying": 0.8}
	)
	
	create_ingredient(
		"ing_sulfur",
		"Sulfur",
		"Yellow mineral with reactive properties.",
		"mineral_elements",
		7,
		3,
		900.0,  # 15 min
		{"reaction": 1.0, "transformation": 0.5}
	)
	
	# Special Elements (just a few examples)
	create_ingredient(
		"ing_morning_dew",
		"Morning Dew",
		"Water collected at dawn with rejuvenating properties.",
		"special_elements",
		10,
		3,
		1440.0,  # 24 min
		{"rejuvenation": 1.0, "purity": 0.9}
	)
	
	create_ingredient(
		"ing_pure_water",
		"Pure Water",
		"Water filtered through special alchemical processes.",
		"special_elements",
		8,
		2,
		600.0,  # 10 min
		{"purity": 1.0, "healing": 0.5}
	)
	
	# Additional ingredients can be added as needed
