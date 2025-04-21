extends Node
## Enhanced property system for combining ingredients and determining potion effects
## Add this script to an autoload in the Project Settings

# Signals
signal properties_calculated(properties)
signal experimental_brewing_result(result)

# Constants
const PROPERTY_THRESHOLD = 0.5  # Minimum threshold for a property to be significant
const PROPERTY_INTERACTIONS = {
	"heating": {
		"cooling": "neutralize",  # These properties neutralize each other
		"transformation": "enhance"  # These properties enhance each other
	},
	"calming": {
		"energy": "neutralize",
		"healing": "enhance",
		"soothing": "enhance"
	},
	"clarity": {
		"focus": "enhance",
		"purifying": "enhance"
	},
	"strength": {
		"durability": "enhance",
		"energy": "enhance"
	},
	"stability": {
		"binding": "enhance",
		"transformation": "reduce"  # These properties reduce each other
	},
	"preservation": {
		"purifying": "enhance",
		"transformation": "reduce"
	},
	"reaction": {
		"transformation": "enhance",
		"stability": "reduce"
	},
	"rejuvenation": {
		"purity": "enhance",
		"healing": "enhance"
	},
	"purity": {
		"healing": "enhance",
		"purifying": "enhance"
	}
}

# Effect templates for experimental brewing
const EFFECT_TEMPLATES = {
	"healing": {
		"name": "Healing Potion",
		"properties": ["healing", "rejuvenation", "purity"],
		"category": "healing"
	},
	"cooling": {
		"name": "Cooling Salve",
		"properties": ["cooling", "soothing"],
		"category": "healing"
	},
	"clarity": {
		"name": "Clarity Potion",
		"properties": ["clarity", "focus"],
		"category": "mind"
	},
	"strength": {
		"name": "Strength Tonic",
		"properties": ["strength", "durability", "energy"],
		"category": "transformation"
	},
	"preservation": {
		"name": "Preservation Solution",
		"properties": ["preservation", "stability"],
		"category": "utility"
	},
	"transformation": {
		"name": "Transformation Elixir",
		"properties": ["transformation", "reaction"],
		"category": "transformation"
	},
	"purification": {
		"name": "Purification Tonic",
		"properties": ["purifying", "purity"],
		"category": "utility"
	},
	"energy": {
		"name": "Energy Draught",
		"properties": ["energy", "reaction"],
		"category": "mind"
	},
	"unknown": {
		"name": "Unknown Mixture",
		"properties": [],
		"category": "utility"
	}
}

# Private variables
var _recipe_manager = null
var _ingredient_manager = null
var _weather_system = null

# Lifecycle methods
func _ready():
	# Get references to needed managers
	_recipe_manager = get_node_or_null("/root/RecipeManager")
	_ingredient_manager = get_node_or_null("/root/IngredientManager")
	_weather_system = get_node_or_null("/root/WeatherSystem")

# Public methods
func calculate_properties(ingredients):
	"""
	Calculates the combined properties from a list of ingredients
	Returns a dictionary of property:strength pairs
	"""
	if not _ingredient_manager:
		return {}
	
	var combined_properties = {}
	var ingredient_count = ingredients.size()
	
	if ingredient_count == 0:
		return combined_properties
	
	# First pass: Add up all properties from all ingredients
	for ingredient_id in ingredients:
		var ingredient = _ingredient_manager.get_ingredient(ingredient_id)
		if not ingredient:
			continue
		
		# Apply weather effects to ingredient properties
		var weather_modifier = 1.0
		if _weather_system:
			if _weather_system.is_ingredient_boosted(ingredient_id):
				weather_modifier = 1.2
			elif _weather_system.is_ingredient_reduced(ingredient_id):
				weather_modifier = 0.8
		
		# Add each property
		for property_name in ingredient.properties:
			var property_value = ingredient.properties[property_name] * weather_modifier
			
			if not combined_properties.has(property_name):
				combined_properties[property_name] = 0
			
			combined_properties[property_name] += property_value
	
	# Second pass: Calculate interactions between properties
	var final_properties = combined_properties.duplicate()
	
	for prop1 in combined_properties:
		if combined_properties[prop1] <= PROPERTY_THRESHOLD:
			continue
			
		if PROPERTY_INTERACTIONS.has(prop1):
			for prop2 in PROPERTY_INTERACTIONS[prop1]:
				if combined_properties.has(prop2) and combined_properties[prop2] > PROPERTY_THRESHOLD:
					var interaction = PROPERTY_INTERACTIONS[prop1][prop2]
					
					match interaction:
						"neutralize":
							# Properties cancel each other out
							var min_value = min(final_properties[prop1], final_properties[prop2])
							final_properties[prop1] -= min_value
							final_properties[prop2] -= min_value
						
						"enhance":
							# Properties boost each other
							var boost = min(final_properties[prop1], final_properties[prop2]) * 0.5
							final_properties[prop1] += boost
							final_properties[prop2] += boost
						
						"reduce":
							# Properties reduce each other
							var reduction = min(final_properties[prop1], final_properties[prop2]) * 0.3
							final_properties[prop1] -= reduction
							final_properties[prop2] -= reduction
	
	# Normalize values and remove insignificant properties
	var filtered_properties = {}
	for property_name in final_properties:
		if final_properties[property_name] > PROPERTY_THRESHOLD:
			filtered_properties[property_name] = final_properties[property_name]
	
	# Apply brewing quality modifier from weather
	if _weather_system:
		var quality_mod = _weather_system.get_brewing_quality_modifier()
		if quality_mod != 0:
			for property_name in filtered_properties:
				filtered_properties[property_name] *= (1.0 + quality_mod)
	
	# Signal the calculated properties
	properties_calculated.emit(filtered_properties)
	
	return filtered_properties

func determine_potion_type(properties):
	"""
	Determines the potion type from a set of properties
	Returns a dictionary with potion details
	"""
	if properties.empty():
		return {
			"type": "unknown",
			"name": "Unknown Mixture",
			"category": "utility",
			"properties": properties
		}
	
	# Find the dominant property
	var dominant_property = ""
	var dominant_value = 0
	
	for property_name in properties:
		if properties[property_name] > dominant_value:
			dominant_value = properties[property_name]
			dominant_property = property_name
	
	# Find matching effect template
	var best_match = "unknown"
	var best_match_score = 0
	
	for template_id in EFFECT_TEMPLATES:
		var template = EFFECT_TEMPLATES[template_id]
		
		# Skip "unknown" template for scoring
		if template_id == "unknown":
			continue
		
		var match_score = 0
		
		# Check if dominant property is in this template
		if dominant_property in template.properties:
			match_score += 2
		
		# Count how many other properties match
		for property_name in properties:
			if property_name in template.properties:
				match_score += 1
		
		# If this is a better match, update best match
		if match_score > best_match_score:
			best_match_score = match_score
			best_match = template_id
	
	# Use the best matching template
	var template = EFFECT_TEMPLATES[best_match]
	
	return {
		"type": best_match,
		"name": template.name,
		"category": template.category,
		"properties": properties
	}

func brew_experimental_potion(ingredients):
	"""
	Creates a potion from experimental brewing
	Returns a dictionary with the result
	"""
	# Calculate properties
	var properties = calculate_properties(ingredients)
	
	# Determine success or failure
	var is_success = true
	var quality_mod = 1.0
	
	# Brewing can fail if:
	# 1. No significant properties
	if properties.empty():
		is_success = false
	
	# 2. Random chance of failure (10%)
	elif randf() < 0.1:
		is_success = false
	
	# Determine result
	var result = {
		"success": is_success,
		"ingredients": ingredients,
		"quality": 1.0 * quality_mod
	}
	
	if is_success:
		# Determine potion type
		var potion_data = determine_potion_type(properties)
		
		# Create or get potion ID
		var potion_id = _get_potion_id_for_properties(potion_data)
		
		# Check if this is a known recipe
		var recipe_id = _find_recipe_for_result(potion_id)
		var is_discovery = recipe_id.empty()
		
		result.potion_id = potion_id
		result.potion_name = potion_data.name
		result.potion_category = potion_data.category
		result.properties = properties
		result.recipe_discovered = not is_discovery
		
		# If this is a new discovery, create an experimental recipe
		if is_discovery and _recipe_manager:
			recipe_id = _recipe_manager.add_experimental_recipe(ingredients, potion_id, potion_data.name, properties)
			result.recipe_discovered = true
			result.recipe_id = recipe_id
		else:
			result.recipe_id = recipe_id
	else:
		# Failed potion
		result.potion_id = "pot_failed_experiment"
		result.potion_name = "Failed Experiment"
		result.potion_category = "utility"
		result.properties = {}
	
	# Signal the result
	experimental_brewing_result.emit(result)
	
	return result

func calculate_potion_quality(brewing_station_level, player_specialization, specialization_type, weather_quality_mod=0):
	"""
	Calculates the quality of a brewed potion based on various factors
	Returns a quality value between 0.5 and 2.0
	"""
	# Base quality
	var quality = 1.0
	
	# Station level bonus (up to +30%)
	quality += (brewing_station_level - 1) * 0.15
	
	# Specialization bonus (up to +25%)
	if player_specialization > 0 and specialization_type != "":
		quality += player_specialization * 0.05
	
	# Weather modifier
	quality += weather_quality_mod
	
	# Random variation (-10% to +10%)
	quality += randf_range(-0.1, 0.1)
	
	# Clamp to valid range
	return clamp(quality, 0.5, 2.0)

# Private methods
func _get_potion_id_for_properties(potion_data):
	"""Gets or generates a potion ID for the given properties"""
	if not _recipe_manager:
		return "pot_unknown_mixture"
	
	var potion_type = potion_data.type
	
	# Check if a standard potion exists for this type
	if potion_type != "unknown":
		var standard_id = "pot_" + potion_type
		var potion = _recipe_manager.get_potion(standard_id)
		if potion:
			return standard_id
	
	# Generate a unique ID for an experimental potion
	var unique_id = "pot_exp_" + potion_type + "_" + str(Time.get_unix_time_from_system())
	return unique_id

func _find_recipe_for_result(potion_id):
	"""Finds a recipe that produces the given potion"""
	if not _recipe_manager:
		return ""
	
	for recipe_id in _recipe_manager.get_all_recipe_ids():
		var recipe = _recipe_manager.get_recipe(recipe_id)
		if recipe and recipe.result_id == potion_id:
			return recipe_id
	
	return ""
