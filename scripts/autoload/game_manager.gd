extends Node
## Main game management singleton that coordinates all game systems
## Add this script to an autoload in the Project Settings

# Signals
signal game_initialized
signal game_day_passed(day_number)
signal game_saved
signal game_loaded

# Constants
const SAVE_FILE_PATH = "user://alchemy_save.json"
const VERSION = "0.0.1"

# Game state variables
var player_level = 1
var player_gold = 0
var player_essence = 0
var player_knowledge_points = 0
var current_game_day = 1
var discovered_recipes = []
var unlocked_stations = ["cauldron"]
var station_levels = {"cauldron": 1}
var specializations = {
	"healing": 0,
	"utility": 0, 
	"transformation": 0,
	"mind": 0
}

# Timer for auto-saving
var _save_timer = null

# Systems references
var inventory_manager = null
var recipe_manager = null
var villager_manager = null
var brewing_system = null
var gathering_system = null

# Lifecycle methods
func _ready():
	_initialize_game()
	_setup_save_timer()

# Public methods
func start_new_game():
	"""Starts a new game with default values"""
	player_level = 1
	player_gold = 10  # Starting gold
	player_essence = 0
	player_knowledge_points = 0
	current_game_day = 1
	discovered_recipes = ["minor_healing_potion"]  # Start with one recipe
	unlocked_stations = ["cauldron"]
	station_levels = {"cauldron": 1}
	specializations = {
		"healing": 0,
		"utility": 0, 
		"transformation": 0,
		"mind": 0
	}
	
	game_initialized.emit()
	save_game()

func advance_game_day():
	"""Advances the game by one day, triggering relevant events"""
	current_game_day += 1
	game_day_passed.emit(current_game_day)
	
	# Refresh daily activities, respawn resources, etc.
	if gathering_system:
		gathering_system.refresh_daily_resources()
	
	if villager_manager:
		villager_manager.refresh_daily_orders()
	
	save_game()

func add_gold(amount):
	"""Adds gold to the player's inventory"""
	player_gold += amount
	save_game()
	return player_gold

func spend_gold(amount):
	"""Tries to spend gold from player's inventory"""
	if player_gold >= amount:
		player_gold -= amount
		save_game()
		return true
	return false

func add_essence(amount):
	"""Adds alchemical essence to the player's inventory"""
	player_essence += amount
	save_game()
	return player_essence

func spend_essence(amount):
	"""Tries to spend essence from player's inventory"""
	if player_essence >= amount:
		player_essence -= amount
		save_game()
		return true
	return false

func discover_recipe(recipe_id):
	"""Marks a recipe as discovered"""
	if recipe_id not in discovered_recipes:
		discovered_recipes.append(recipe_id)
		save_game()
		return true
	return false

func add_specialization_point(specialization_type):
	"""Adds a point to the specified specialization path"""
	if specialization_type in specializations:
		specializations[specialization_type] += 1
		save_game()
		return true
	return false

func unlock_station(station_id):
	"""Unlocks a new workshop station"""
	if station_id not in unlocked_stations:
		unlocked_stations.append(station_id)
		station_levels[station_id] = 1
		save_game()
		return true
	return false

func upgrade_station(station_id):
	"""Upgrades a workshop station level"""
	if station_id in station_levels:
		station_levels[station_id] += 1
		save_game()
		return true
	return false

func save_game():
	"""Saves the game state to a file"""
	var save_data = {
		"version": VERSION,
		"player_level": player_level,
		"player_gold": player_gold,
		"player_essence": player_essence,
		"player_knowledge_points": player_knowledge_points,
		"current_game_day": current_game_day,
		"discovered_recipes": discovered_recipes,
		"unlocked_stations": unlocked_stations,
		"station_levels": station_levels,
		"specializations": specializations,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Save inventory, if initialized
	if inventory_manager:
		save_data["inventory"] = inventory_manager.get_save_data()
	
	# Save villager data, if initialized
	if villager_manager:
		save_data["villagers"] = villager_manager.get_save_data()
	
	# Save recipe data, if initialized
	if recipe_manager:
		save_data["recipes"] = recipe_manager.get_save_data()
	
	# Create save file
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "  "))
		file.close()
		
		game_saved.emit()
		return true
	return false

func load_game():
	"""Loads the game state from a file"""
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return false
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		return false
		
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		return false
	
	var save_data = json.get_data()
	
	# Load basic player data
	player_level = save_data.get("player_level", 1)
	player_gold = save_data.get("player_gold", 0)
	player_essence = save_data.get("player_essence", 0)
	player_knowledge_points = save_data.get("player_knowledge_points", 0)
	current_game_day = save_data.get("current_game_day", 1)
	discovered_recipes = save_data.get("discovered_recipes", [])
	unlocked_stations = save_data.get("unlocked_stations", ["cauldron"])
	station_levels = save_data.get("station_levels", {"cauldron": 1})
	specializations = save_data.get("specializations", {
		"healing": 0,
		"utility": 0, 
		"transformation": 0,
		"mind": 0
	})
	
	# Load additional system data
	if inventory_manager and save_data.has("inventory"):
		inventory_manager.load_save_data(save_data["inventory"])
	
	if villager_manager and save_data.has("villagers"):
		villager_manager.load_save_data(save_data["villagers"])
	
	if recipe_manager and save_data.has("recipes"):
		recipe_manager.load_save_data(save_data["recipes"])
	
	game_loaded.emit()
	return true

# Private methods
func _initialize_game():
	"""Initialize the game state"""
	# Check for existing save
	if FileAccess.file_exists(SAVE_FILE_PATH):
		load_game()
	else:
		start_new_game()

func _setup_save_timer():
	"""Sets up automatic saving every few minutes"""
	_save_timer = Timer.new()
	_save_timer.wait_time = 300  # Save every 5 minutes
	_save_timer.one_shot = false
	_save_timer.timeout.connect(_on_save_timer_timeout)
	add_child(_save_timer)
	_save_timer.start()

func _on_save_timer_timeout():
	"""Called when the save timer expires"""
	save_game()

func _notification(what):
	"""Handle notifications like app going to background"""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Game is being closed
		save_game()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# Game lost focus (e.g., app went to background)
		save_game()
