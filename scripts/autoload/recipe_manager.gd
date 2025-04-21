extends Node
## Manages all recipe data and brewing outcomes
## Add this script to an autoload in the Project Settings

# Signals
signal recipes_loaded
signal recipe_discovered(recipe_id)
signal experimental_recipe_created(recipe_id)

# Private variables
var _recipes = {}  # Dictionary of recipe_id: Recipe resource
var _potions = {}  # Dictionary of potion_id: Potion data
var _recipes_by_category = {}  # Dictionary of category: [recipe_ids]
var _recipes_by_result = {}  # Dictionary of result_id: recipe_id

# Lifecycle methods
func _ready():
	# Load all recipe data
	_load_recipes()
	_load_potions()
	
	# Register with GameManager
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.recipe_manager = self

# Public methods
func get_recipe(recipe_id):
	"""Returns the recipe with the given ID or null if not found"""
	if _recipes.has(recipe_id):
		return _recipes[recipe_id]
	return null

func get_recipes_by_category(category):
	"""Returns a list of recipe IDs in the given category"""
	if _recipes_by_category.has(category):
		return _recipes_by_category[category].duplicate()
	return []

func get_discovered_recipes():
	"""Returns a list of all discovered recipe IDs"""
	var discovered = []
	
	for recipe_id in _recipes:
		var recipe = _recipes[recipe_id]
		if recipe.discovered:
			discovered.append(recipe_id)
	
	return discovered

func get_potion(potion_id):
	"""Returns the potion data for the given ID or null if not found"""
	if _potions.has(potion_id):
		return _potions[potion_id]
	return null

func discover_recipe(recipe_id):
	"""Marks a recipe as discovered"""
	if not _recipes.has(recipe_id):
		return false
	
	var recipe = _recipes[recipe_id]
	if recipe.discovered:
		return false
	
	recipe.discovered = true
	recipe_discovered.emit(recipe_id)
	
	# Also update GameManager if available
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.discover_recipe(recipe_id)
	
	return true

func find_recipe_by_ingredients(ingredients):
	"""Tries to find a recipe with exactly the given ingredients"""
	for recipe_id in _recipes:
		var recipe = _recipes[recipe_id]
		
		# Check if ingredient counts match
		if recipe.ingredients.size() != ingredients.size():
			continue
		
		# Check if all ingredients match
		var all_match = true
		for ing in recipe.ingredients:
			if not ing in ingredients:
				all_match = false
				break
		
		if all_match:
			return {
				"found": true,
				"recipe_id": recipe_id,
				"recipe_name": recipe.name
			}
	
	return {"found": false}

func get_recipe_by_result(potion_id):
	"""Finds a recipe that produces the given potion"""
	if _recipes_by_result.has(potion_id):
		return get_recipe(_recipes_by_result[potion_id])
	return null

func add_recipe(recipe):
	"""Adds a recipe to the system"""
	if not recipe or not recipe is Recipe:
		return false
	
	var recipe_id = recipe.id
	
	# Add to recipes dictionary
	_recipes[recipe_id] = recipe
	
	# Add to category list
	var category = recipe.category
	if not _recipes_by_category.has(category):
		_recipes_by_category[category] = []
	
	if not recipe_id in _recipes_by_category[category]:
		_recipes_by_category[category].append(recipe_id)
	
	# Add to result lookup
	_recipes_by_result[recipe.result_id] = recipe_id
	
	return true

func create_experimental_recipe(properties, ingredients):
	"""Creates a new recipe based on experimental brewing properties"""
	var recipe_id = "recipe_experimental_" + str(Time.get_unix_time_from_system())
	
	# Determine the category based on dominant property
	var category = _determine_category_from_properties(properties)
	
	# Create a descriptive name
	var name = _generate_recipe_name(properties)
	var description = "An experimental recipe discovered through experimentation."
	
	# Create the recipe
	var new_recipe = Recipe.new(
		recipe_id,
		name,
		description,
		category,
		ingredients.duplicate(),
		"pot_experimental_" + str(Time.get_unix_time_from_system()), # Generate a unique potion ID
		1, # Difficulty level 1
		true # Already discovered
	)
	
	# Also create the corresponding potion
	var new_potion = {
		"id": new_recipe.result_id,
		"name": name,
		"description": description,
		"category": category,
		"base_value": _calculate_potion_value(properties),
		"properties": properties.duplicate()
	}
	
	# Add to systems
	add_recipe(new_recipe)
	_potions[new_recipe.result_id] = new_potion
	
	experimental_recipe_created.emit(recipe_id)
	return recipe_id

func get_recipe_difficulty(recipe_id):
	"""Gets the difficulty level of a recipe"""
	if _recipes.has(recipe_id):
		return _recipes[recipe_id].difficulty
	return 0

func get_save_data():
	"""Returns a dictionary with data that needs to be saved"""
	var save_data = {
		"discovered_recipes": []
	}
	
	# Save discovered recipes
	for recipe_id in _recipes:
		var recipe = _recipes[recipe_id]
		if recipe.discovered:
			save_data.discovered_recipes.append(recipe_id)
	
	return save_data

func load_save_data(data):
	"""Loads saved recipe data"""
	if data.has("discovered_recipes"):
		# Mark recipes as discovered
		for recipe_id in data.discovered_recipes:
			if _recipes.has(recipe_id):
				_recipes[recipe_id].discovered = true

# Private methods
func _load_recipes():
	"""Loads all recipe definitions"""
	# Clear existing data
	_recipes.clear()
	_recipes_by_category.clear()
	_recipes_by_result.clear()
	
	# Setup basic categories
	_recipes_by_category = {
		"healing": [],
		"utility": [],
		"transformation": [],
		"mind": []
	}
	
	# Load from data file if it exists
	var file_path = "res://data/recipes.json"
	
	if FileAccess.file_exists(file_path):
		# Load from JSON file
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var json_result = json.parse(json_text)
		if json_result == OK:
			var recipes_data = json.data
			
			# Create recipes from data
			for recipe_data in recipes_data:
				var recipe = Recipe.new()
				recipe.from_dict(recipe_data)
				add_recipe(recipe)
		else:
			push_error("Failed to parse recipes JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
			# Fall back to hardcoded recipes
			_create_default_recipes()
	else:
		# Fall back to hardcoded recipes
		_create_default_recipes()
	
	# Get discovered recipes from GameManager
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		for recipe_id in game_manager.discovered_recipes:
			if _recipes.has(recipe_id):
				_recipes[recipe_id].discovered = true
	
	recipes_loaded.emit()

func _load_potions():
	"""Loads all potion definitions"""
	# Clear existing data
	_potions.clear()
	
	# Load from data file if it exists
	var file_path = "res://data/potions.json"
	
	if FileAccess.file_exists(file_path):
		# Load from JSON file
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var json_result = json.parse(json_text)
		if json_result == OK:
			var potions_data = json.data
			
			# Store potions data
			for potion_data in potions_data:
				_potions[potion_data.id] = potion_data
		else:
			push_error("Failed to parse potions JSON: " + json.get_error_message() + " at line " + str(json.get_error_line()))
			# Fall back to hardcoded potions
			_create_default_potions()
	else:
		# Fall back to hardcoded potions
		_create_default_potions()

func _create_default_recipes():
	"""Creates default recipe definitions if data file is missing"""
	# Minor Healing Potion
	var recipe1 = Recipe.new(
		"recipe_minor_healing",
		"Minor Healing Potion",
		"A simple potion that heals minor wounds.",
		"healing",
		["ing_chamomile", "ing_pure_water"],
		"pot_minor_healing",
		1, # Difficulty level
		true # Discovered by default
	)
	add_recipe(recipe1)
	
	# Cooling Salve
	var recipe2 = Recipe.new(
		"recipe_cooling_salve",
		"Cooling Salve",
		"A soothing balm for burns and inflammation.",
		"healing",
		["ing_mint", "ing_clay", "ing_pure_water"],
		"pot_cooling_salve",
		2, # Difficulty level
		false # Not discovered by default
	)
	add_recipe(recipe2)
	
	# Polishing Solution
	var recipe3 = Recipe.new(
		"recipe_polishing_solution",
		"Polishing Solution",
		"Used for cleaning and polishing metal objects.",
		"utility",
		["ing_salt", "ing_lavender", "ing_pure_water"],
		"pot_polishing_solution",
		1, # Difficulty level
		false # Not discovered by default
	)
	add_recipe(recipe3)
	
	# Clarity Potion
	var recipe4 = Recipe.new(
		"recipe_clarity_potion",
		"Clarity Potion",
		"Enhances mental focus and clarity of thought.",
		"mind",
		["ing_sage", "ing_quartz_dust", "ing_pure_water"],
		"pot_clarity",
		2, # Difficulty level
		false # Not discovered by default
	)
	add_recipe(recipe4)
	
	# Strength Tonic
	var recipe5 = Recipe.new(
		"recipe_strength_tonic",
		"Strength Tonic",
		"Temporarily boosts physical strength.",
		"transformation",
		["ing_iron_filings", "ing_mushrooms", "ing_sulfur"],
		"pot_strength_tonic",
		3, # Difficulty level
		false # Not discovered by default
	)
	add_recipe(recipe5)

func _create_default_potions():
	"""Creates default potion definitions if data file is missing"""
	# Minor Healing Potion
	_potions["pot_minor_healing"] = {
		"id": "pot_minor_healing",
		"name": "Minor Healing Potion",
		"description": "A simple potion that heals minor wounds.",
		"category": "healing",
		"base_value": 5,
		"properties": {
			"healing": 1.0,
			"duration": 0.5
		}
	}
	
	# Cooling Salve
	_potions["pot_cooling_salve"] = {
		"id": "pot_cooling_salve",
		"name": "Cooling Salve",
		"description": "A soothing balm for burns and inflammation.",
		"category": "healing",
		"base_value": 8,
		"properties": {
			"healing": 0.7,
			"cooling": 1.2,
			"duration": 1.0
		}
	}
	
	# Polishing Solution
	_potions["pot_polishing_solution"] = {
		"id": "pot_polishing_solution",
		"name": "Polishing Solution",
		"description": "Used for cleaning and polishing metal objects.",
		"category": "utility",
		"base_value": 4,
		"properties": {
			"cleaning": 1.0,
			"preservation": 0.5
		}
	}
	
	# Clarity Potion
	_potions["pot_clarity"] = {
		"id": "pot_clarity",
		"name": "Clarity Potion",
		"description": "Enhances mental focus and clarity of thought.",
		"category": "mind",
		"base_value": 10,
		"properties": {
			"clarity": 1.2,
			"focus": 0.8,
			"duration": 1.5
		}
	}
	
	# Strength Tonic
	_potions["pot_strength_tonic"] = {
		"id": "pot_strength_tonic",
		"name": "Strength Tonic",
		"description": "Temporarily boosts physical strength.",
		"category": "transformation",
		"base_value": 12,
		"properties": {
			"strength": 1.5,
			"duration": 2.0,
			"energy": 0.7
		}
	}
	
	# Unknown Mixture
	_potions["pot_unknown_mixture"] = {
		"id": "pot_unknown_mixture",
		"name": "Unknown Mixture",
		"description": "An unidentified concoction. Effects unknown.",
		"category": "utility",
		"base_value": 1,
		"properties": {}
	}
	
	# Failed Experiment
	_potions["pot_failed_experiment"] = {
		"id": "pot_failed_experiment",
		"name": "Failed Experiment",
		"description": "A failed brewing attempt. Possibly useful as a reagent.",
		"category": "utility",
		"base_value": 1,
		"properties": {
			"reagent": 0.5
		}
	}

func _determine_category_from_properties(properties):
	"""Determines the most appropriate category based on properties"""
	var category_scores = {
		"healing": 0,
		"utility": 0,
		"transformation": 0,
		"mind": 0
	}
	
	# Define property categories
	var property_categories = {
		"healing": ["healing", "soothing", "rejuvenation"],
		"utility": ["cleaning", "preservation", "durability", "binding"],
		"transformation": ["strength", "growth", "transformation", "energy"],
		"mind": ["clarity", "focus", "calming", "soothing"]
	}
	
	# Score properties
	for prop in properties:
		var prop_value = properties[prop]
		
		for cat in property_categories:
			if prop in property_categories[cat]:
				category_scores[cat] += prop_value
	
	# Determine highest scoring category
	var highest_score = 0
	var highest_category = "utility"  # Default
	
	for cat in category_scores:
		if category_scores[cat] > highest_score:
			highest_score = category_scores[cat]
			highest_category = cat
	
	return highest_category

func _generate_recipe_name(properties):
	"""Generates a name for a recipe based on its properties"""
	var prefixes = {
		"healing": ["Healing", "Restorative", "Curative", "Mending"],
		"utility": ["Practical", "Useful", "Functional", "Handy"],
		"transformation": ["Transformative", "Altering", "Changing", "Shifting"],
		"mind": ["Mind", "Mental", "Cognitive", "Psychic"]
	}
	
	var suffixes = {
		"healing": ["Elixir", "Salve", "Remedy", "Balm"],
		"utility": ["Solution", "Mixture", "Compound", "Concoction"],
		"transformation": ["Tonic", "Brew", "Serum", "Essence"],
		"mind": ["Potion", "Draught", "Infusion", "Tincture"]
	}
	
	# Determine strongest property
	var strongest_prop = ""
	var strongest_value = 0
	
	for prop in properties:
		if properties[prop] > strongest_value:
			strongest_value = properties[prop]
			strongest_prop = prop
	
	# Determine category
	var category = _determine_category_from_properties(properties)
	
	# Generate name
	var prefix_list = prefixes[category]
	var suffix_list = suffixes[category]
	
	var prefix = prefix_list[randi() % prefix_list.size()]
	var suffix = suffix_list[randi() % suffix_list.size()]
	
	return prefix + " " + strongest_prop.capitalize() + " " + suffix

func _calculate_potion_value(properties):
	"""Calculates a potion's value based on its properties"""
	var total_value = 0
	
	for prop in properties:
		total_value += properties[prop] * 5  # Each property point worth 5 gold
	
	# Add a base value
	total_value += 3
	
	# Ensure minimum value of 1
	return max(1, total_value)
