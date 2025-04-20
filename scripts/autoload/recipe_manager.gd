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

func get_all_recipe_ids():
	"""Returns a list of all recipe IDs"""
	return _recipes.keys()

func get_discovered_recipes():
	"""Returns a list of all discovered recipe IDs"""
	var discovered = []
	for recipe_id in _recipes:
		if _recipes[recipe_id].discovered:
			discovered.append(recipe_id)
	return discovered

func get_potion(potion_id):
	"""Returns data for the given potion ID"""
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
	
	# Update GameManager discovered recipes
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.discover_recipe(recipe_id)
	
	recipe_discovered.emit(recipe_id)
	return true

func add_experimental_recipe(ingredient_ids, result_id, name="", properties={}):
	"""
	Adds a new experimental recipe discovered by the player
	Returns the new recipe ID if successful
	"""
	if ingredient_ids.empty() or result_id.empty():
		return ""
	
	# Create a unique ID for the experimental recipe
	var recipe_id = "recipe_exp_" + result_id.substr(4) + "_" + str(Time.get_unix_time_from_system())
	
	# Create recipe name if not provided
	if name.empty():
		name = "Experimental " + result_id.substr(4).capitalize() + " Recipe"
	
	# Create the recipe
	var recipe = Recipe.new()
	recipe.id = recipe_id
	recipe.name = name
	recipe.description = "A recipe you discovered through experimentation."
	recipe.ingredients = ingredient_ids.duplicate()
	recipe.result_id = result_id
	recipe.discovered = true
	recipe.experimental = true
	recipe.properties = properties
	
	# Determine category based on result
	if _potions.has(result_id):
		recipe.category = _potions[result_id].category
	
	# Add to recipes
	_recipes[recipe_id] = recipe
	
	# Add to category list
	var category = recipe.category
	if not _recipes_by_category.has(category):
		_recipes_by_category[category] = []
	
	if not recipe_id in _recipes_by_category[category]:
		_recipes_by_category[category].append(recipe_id)
	
	# Add to result lookup
	_recipes_by_result[result_id] = recipe_id
	
	# Update GameManager discovered recipes
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.discover_recipe(recipe_id)
	
	experimental_recipe_created.emit(recipe_id)
	return recipe_id

func find_recipe_by_ingredients(ingredient_ids):
	"""
	Tries to find a recipe matching the given ingredients
	Returns a dictionary with found status and recipe details
	"""
	if ingredient_ids.empty():
		return {"found": false}
	
	# Sort ingredients for consistent comparison
	var sorted_ingredients = ingredient_ids.duplicate()
	sorted_ingredients.sort()
	
	# Check exact matches first
	for recipe_id in _recipes:
		var recipe = _recipes[recipe_id]
		
		# Skip if recipe requires different number of ingredients
		if recipe.ingredients.size() != sorted_ingredients.size():
			continue
		
		# Sort recipe ingredients for comparison
		var recipe_ingredients = recipe.ingredients.duplicate()
		recipe_ingredients.sort()
		
		# Check for exact match
		var exact_match = true
		for i in range(recipe_ingredients.size()):
			if recipe_ingredients[i] != sorted_ingredients[i]:
				exact_match = false
				break
		
		if exact_match:
			return {
				"found": true,
				"recipe_id": recipe_id,
				"recipe_name": recipe.name,
				"match_percent": 1.0,
				"discovered": recipe.discovered
			}
	
	# No exact match found, look for partial matches
	var best_match = null
	var best_match_percent = 0.0
	
	for recipe_id in _recipes:
		var recipe = _recipes[recipe_id]
		var match_percent = recipe.matches_ingredients(sorted_ingredients)
		
		if match_percent > best_match_percent:
			best_match = recipe
			best_match_percent = match_percent
	
	# Return best partial match if it's close enough
	if best_match != null and best_match_percent >= 0.6:  # At least 60% match
		return {
			"found": true,
			"recipe_id": best_match.id,
			"recipe_name": best_match.name,
			"match_percent": best_match_percent,
			"discovered": best_match.discovered
		}
	
	return {"found": false}

func get_save_data():
	"""Returns a dictionary with all data needed to save recipe state"""
	var save_data = {
		"discovered_recipes": [],
		"experimental_recipes": []
	}
	
	# Save discovered status
	for recipe_id in _recipes:
		var recipe = _recipes[recipe_id]
		if recipe.discovered:
			save_data.discovered_recipes.append(recipe_id)
		
		# Save experimental recipes
		if recipe.experimental:
			save_data.experimental_recipes.append(recipe.to_dict())
	
	return save_data

func load_save_data(data):
	"""Loads recipe state from saved data"""
	if data.has("discovered_recipes"):
		for recipe_id in data.discovered_recipes:
			if _recipes.has(recipe_id):
				_recipes[recipe_id].discovered = true
	
	# Load experimental recipes
	if data.has("experimental_recipes"):
		for recipe_data in data.experimental_recipes:
			var recipe = Recipe.new()
			recipe.from_dict(recipe_data)
			
			# Add to recipes
			_recipes[recipe.id] = recipe
			
			# Add to category list
			var category = recipe.category
			if not _recipes_by_category.has(category):
				_recipes_by_category[category] = []
			
			if not recipe.id in _recipes_by_category[category]:
				_recipes_by_category[category].append(recipe.id)
			
			# Add to result lookup
			_recipes_by_result[recipe.result_id] = recipe.id

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
		if file:
			var json_text = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var error = json.parse(json_text)
			
			if error == OK:
				var recipes_data = json.get_data()
				
				# Create recipes from data
				for recipe_data in recipes_data:
					var recipe = Recipe.new()
					recipe.from_dict(recipe_data)
					_add_recipe(recipe)
			else:
				push_error("Failed to parse recipes JSON: " + json.get_error_message())
				# Fall back to hardcoded recipes
				_create_default_recipes()
		else:
			# Fall back to hardcoded recipes if file can't be opened
			_create_default_recipes()
	else:
		# Fall back to hardcoded recipes if file doesn't exist
		_create_default_recipes()
	
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
		if file:
			var json_text = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var error = json.parse(json_text)
			
			if error == OK:
				var potions_data = json.get_data()
				
				# Add potions from data
				for potion_data in potions_data:
					var potion_id = potion_data.id
					_potions[potion_id] = potion_data
			else:
				push_error("Failed to parse potions JSON: " + json.get_error_message())
				# Fall back to hardcoded potions
				_create_default_potions()
		else:
			# Fall back to hardcoded potions if file can't be opened
			_create_default_potions()
	else:
		# Fall back to hardcoded potions if file doesn't exist
		_create_default_potions()

func _add_recipe(recipe):
	"""Adds a recipe to the internal collections"""
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

func _create_default_recipes():
	"""Creates default recipe definitions if data file is missing"""
	# Healing Potions
	var minor_healing = Recipe.new(
		"recipe_minor_healing",
		"Minor Healing Potion",
		"A simple potion that heals minor wounds.",
		"healing",
		["ing_chamomile", "ing_pure_water"],
		"pot_minor_healing",
		1  # Difficulty
	)
	minor_healing.properties = {"healing": 1.0, "duration": 0.5}
	minor_healing.discovered = true  # Start with this recipe known
	_add_recipe(minor_healing)
	
	var cooling_salve = Recipe.new(
		"recipe_cooling_salve",
		"Cooling Salve",
		"A soothing balm for burns and inflammation.",
		"healing",
		["ing_mint", "ing_clay", "ing_pure_water"],
		"pot_cooling_salve",
		2  # Difficulty
	)
	cooling_salve.properties = {"healing": 0.7, "cooling": 1.2, "duration": 1.0}
	_add_recipe(cooling_salve)
	
	# Utility Potions
	var polishing_solution = Recipe.new(
		"recipe_polishing_solution",
		"Polishing Solution",
		"Used for cleaning and polishing metal objects.",
		"utility",
		["ing_salt", "ing_vinegar", "ing_pure_water"],
		"pot_polishing_solution",
		1  # Difficulty
	)
	polishing_solution.properties = {"cleaning": 1.0, "preservation": 0.5}
	_add_recipe(polishing_solution)
	
	# Add more default recipes as needed

func _create_default_potions():
	"""Creates default potion definitions if data file is missing"""
	_potions = {
		"pot_minor_healing": {
			"id": "pot_minor_healing",
			"name": "Minor Healing Potion",
			"description": "A simple potion that heals minor wounds.",
			"category": "healing",
			"base_value": 5,
			"properties": {"healing": 1.0, "duration": 0.5}
		},
		"pot_cooling_salve": {
			"id": "pot_cooling_salve",
			"name": "Cooling Salve",
			"description": "A soothing balm for burns and inflammation.",
			"category": "healing",
			"base_value": 8,
			"properties": {"healing": 0.7, "cooling": 1.2, "duration": 1.0}
		},
		"pot_polishing_solution": {
			"id": "pot_polishing_solution",
			"name": "Polishing Solution",
			"description": "Used for cleaning and polishing metal objects.",
			"category": "utility",
			"base_value": 4,
			"properties": {"cleaning": 1.0, "preservation": 0.5}
		},
		"pot_unknown_mixture": {
			"id": "pot_unknown_mixture",
			"name": "Unknown Mixture",
			"description": "An unidentified concoction. Effects unknown.",
			"category": "utility",
			"base_value": 1,
			"properties": {}
		},
		"pot_failed_experiment": {
			"id": "pot_failed_experiment",
			"name": "Failed Experiment",
			"description": "A failed brewing attempt. Possibly useful as a reagent.",
			"category": "utility",
			"base_value": 1,
			"properties": {"reagent": 0.5}
		}
	}
