extends Node
## Weather system that affects ingredient gathering and brewing
## Add this script to an autoload in the Project Settings

# Signals
signal weather_changed(old_weather, new_weather)
signal season_changed(old_season, new_season)

# Constants
const WEATHER_TYPES = {
	"clear": {
		"name": "Clear",
		"description": "A beautiful clear day",
		"icon": "weather_clear.png",
		"effects": {
			"brewing_quality": 0,
			"gathering_chance": 0
		}
	},
	"rainy": {
		"name": "Rainy",
		"description": "A rainy day - water-based ingredients are more abundant",
		"icon": "weather_rainy.png",
		"effects": {
			"brewing_quality": -0.1,
			"gathering_chance": 0.1,
			"boost_categories": ["special_elements"],
			"boost_ingredients": ["ing_pure_water", "ing_morning_dew"]
		}
	},
	"foggy": {
		"name": "Foggy",
		"description": "A foggy day - mushrooms and herbs are more visible",
		"icon": "weather_foggy.png",
		"effects": {
			"brewing_quality": 0.05,
			"gathering_chance": 0.05,
			"boost_categories": ["common_plants"],
			"boost_ingredients": ["ing_mushrooms"]
		}
	},
	"windy": {
		"name": "Windy",
		"description": "A windy day - flowers and lightweight ingredients are harder to gather",
		"icon": "weather_windy.png",
		"effects": {
			"brewing_quality": 0,
			"gathering_chance": -0.05,
			"boost_categories": ["mineral_elements"],
			"reduction_ingredients": ["ing_lavender", "ing_chamomile", "ing_quartz_dust"]
		}
	},
	"stormy": {
		"name": "Stormy",
		"description": "A stormy day - special energy-infused ingredients may appear",
		"icon": "weather_stormy.png",
		"effects": {
			"brewing_quality": 0.2,
			"gathering_chance": -0.1,
			"boost_ingredients": ["ing_morning_dew", "ing_sulfur"],
			"special_spawns": ["ing_thunder_essence"]
		}
	},
	"hot": {
		"name": "Hot",
		"description": "A scorching hot day - fire elements are enhanced but water is scarce",
		"icon": "weather_hot.png",
		"effects": {
			"brewing_quality": 0.1,
			"gathering_chance": -0.05,
			"boost_ingredients": ["ing_fire_ash", "ing_sulfur"],
			"reduction_ingredients": ["ing_pure_water", "ing_morning_dew"]
		}
	},
	"snowy": {
		"name": "Snowy",
		"description": "A snowy day - cold-preserved ingredients are more potent",
		"icon": "weather_snowy.png",
		"effects": {
			"brewing_quality": 0.15,
			"gathering_chance": -0.1,
			"boost_ingredients": ["ing_frost_crystal", "ing_pure_water"],
			"reduction_categories": ["common_plants"]
		}
	}
}

const SEASONS = {
	"spring": {
		"name": "Spring",
		"description": "A time of growth and renewal",
		"icon": "season_spring.png",
		"weather_chances": {
			"clear": 0.4,
			"rainy": 0.3,
			"foggy": 0.2,
			"windy": 0.1
		},
		"seasonal_ingredients": ["ing_spring_blossom", "ing_fresh_sprout"]
	},
	"summer": {
		"name": "Summer",
		"description": "The warmest season with occasional storms",
		"icon": "season_summer.png",
		"weather_chances": {
			"clear": 0.5,
			"hot": 0.3,
			"stormy": 0.1,
			"rainy": 0.1
		},
		"seasonal_ingredients": ["ing_sunflower", "ing_fire_ash"]
	},
	"autumn": {
		"name": "Autumn",
		"description": "A season of harvest and changing colors",
		"icon": "season_autumn.png",
		"weather_chances": {
			"clear": 0.3,
			"windy": 0.3,
			"rainy": 0.2,
			"foggy": 0.2
		},
		"seasonal_ingredients": ["ing_autumn_leaf", "ing_mushrooms"]
	},
	"winter": {
		"name": "Winter",
		"description": "The coldest season with snow and frost",
		"icon": "season_winter.png",
		"weather_chances": {
			"snowy": 0.4,
			"clear": 0.3,
			"foggy": 0.2,
			"windy": 0.1
		},
		"seasonal_ingredients": ["ing_frost_crystal", "ing_winter_root"]
	}
}

# Current weather state
var current_weather = "clear"
var current_season = "spring"
var weather_duration = 1  # How many days this weather will last
var weather_day_counter = 0  # How many days the current weather has been active

# Lifecycle methods
func _ready():
	# Initialize the weather system
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.game_day_passed.connect(_on_game_day_passed)
		
		# Set the initial season based on game day
		_calculate_season(game_manager.current_game_day)
		
		# Roll initial weather
		_roll_new_weather()

# Public methods
func get_current_weather():
	"""Returns details about the current weather"""
	if WEATHER_TYPES.has(current_weather):
		var weather_data = WEATHER_TYPES[current_weather].duplicate()
		weather_data.id = current_weather
		return weather_data
	return null

func get_current_season():
	"""Returns details about the current season"""
	if SEASONS.has(current_season):
		var season_data = SEASONS[current_season].duplicate()
		season_data.id = current_season
		return season_data
	return null

func get_weather_effect(effect_name):
	"""Gets the value of a specific weather effect"""
	if not WEATHER_TYPES.has(current_weather):
		return 0
	
	var weather = WEATHER_TYPES[current_weather]
	if not weather.effects.has(effect_name):
		return 0
	
	return weather.effects[effect_name]

func is_ingredient_boosted(ingredient_id):
	"""Checks if an ingredient is boosted by current weather"""
	if not WEATHER_TYPES.has(current_weather):
		return false
	
	var weather = WEATHER_TYPES[current_weather]
	
	# Check direct ingredient boost
	if weather.effects.has("boost_ingredients") and ingredient_id in weather.effects.boost_ingredients:
		return true
	
	# Check category boost
	if weather.effects.has("boost_categories"):
		var ingredient_manager = get_node_or_null("/root/IngredientManager")
		if ingredient_manager:
			var ingredient = ingredient_manager.get_ingredient(ingredient_id)
			if ingredient and ingredient.category in weather.effects.boost_categories:
				return true
	
	return false

func is_ingredient_reduced(ingredient_id):
	"""Checks if an ingredient is reduced by current weather"""
	if not WEATHER_TYPES.has(current_weather):
		return false
	
	var weather = WEATHER_TYPES[current_weather]
	
	# Check direct ingredient reduction
	if weather.effects.has("reduction_ingredients") and ingredient_id in weather.effects.reduction_ingredients:
		return true
	
	# Check category reduction
	if weather.effects.has("reduction_categories"):
		var ingredient_manager = get_node_or_null("/root/IngredientManager")
		if ingredient_manager:
			var ingredient = ingredient_manager.get_ingredient(ingredient_id)
			if ingredient and ingredient.category in weather.effects.reduction_categories:
				return true
	
	return false

func get_brewing_quality_modifier():
	"""Gets the brewing quality modifier from current weather"""
	return get_weather_effect("brewing_quality")

func get_gathering_chance_modifier():
	"""Gets the gathering chance modifier from current weather"""
	return get_weather_effect("gathering_chance")

func get_seasonal_ingredients():
	"""Gets ingredients that are in season currently"""
	if not SEASONS.has(current_season):
		return []
	
	return SEASONS[current_season].seasonal_ingredients.duplicate()

func force_weather_change(weather_type):
	"""Forces the weather to change to a specific type"""
	if not WEATHER_TYPES.has(weather_type):
		return false
	
	var old_weather = current_weather
	current_weather = weather_type
	weather_duration = randi_range(1, 3)  # Random duration
	weather_day_counter = 0
	
	weather_changed.emit(old_weather, current_weather)
	return true

func get_save_data():
	"""Returns a dictionary with weather state for saving"""
	return {
		"current_weather": current_weather,
		"current_season": current_season,
		"weather_duration": weather_duration,
		"weather_day_counter": weather_day_counter
	}

func load_save_data(data):
	"""Loads weather state from saved data"""
	if data.has("current_weather"):
		current_weather = data.current_weather
	
	if data.has("current_season"):
		current_season = data.current_season
	
	if data.has("weather_duration"):
		weather_duration = data.weather_duration
	
	if data.has("weather_day_counter"):
		weather_day_counter = data.weather_day_counter

# Private methods
func _roll_new_weather():
	"""Randomly determines a new weather type based on season"""
	if not SEASONS.has(current_season):
		current_weather = "clear"
		return
	
	var season_data = SEASONS[current_season]
	var weather_chances = season_data.weather_chances
	
	# Generate a random value
	var rand_val = randf()
	var cumulative_chance = 0
	
	# Determine weather based on chances
	for weather_type in weather_chances:
		cumulative_chance += weather_chances[weather_type]
		if rand_val <= cumulative_chance:
			var old_weather = current_weather
			current_weather = weather_type
			weather_duration = randi_range(1, 3)  # Weather lasts 1-3 days
			weather_day_counter = 0
			
			# Signal weather change
			if old_weather != current_weather:
				weather_changed.emit(old_weather, current_weather)
			return
	
	# Fallback to clear weather
	current_weather = "clear"

func _calculate_season(day_number):
	"""Calculates the current season based on the game day"""
	# Each season lasts 30 game days (approximately)
	var season_length = 30
	var day_in_year = ((day_number - 1) % (season_length * 4)) + 1
	var old_season = current_season
	
	if day_in_year <= season_length:
		current_season = "spring"
	elif day_in_year <= season_length * 2:
		current_season = "summer"
	elif day_in_year <= season_length * 3:
		current_season = "autumn"
	else:
		current_season = "winter"
	
	# Signal season change if needed
	if old_season != current_season:
		season_changed.emit(old_season, current_season)

func _update_weather():
	"""Updates weather based on duration counter"""
	weather_day_counter += 1
	
	# Check if weather should change
	if weather_day_counter >= weather_duration:
		_roll_new_weather()
	
	# Update any visual effects or system notifications
	var notification_system = get_node_or_null("/root/NotificationSystem")
	if notification_system and WEATHER_TYPES.has(current_weather):
		notification_system.show_info("Today's Weather: " + WEATHER_TYPES[current_weather].name + "\n" + WEATHER_TYPES[current_weather].description, 5.0)

# Signal handlers
func _on_game_day_passed(day_number):
	"""Called when a game day passes"""
	# Calculate season
	_calculate_season(day_number)
	
	# Update weather
	_update_weather()
