extends Node
## Main Game Manager handles global game state and systems

# Signals
signal game_initialized
signal game_loaded
signal game_saved
signal game_day_passed(day_number)
signal gold_changed(new_amount)
signal essence_changed(new_amount)
signal experience_gained(amount)
signal level_up(new_level)

# Game state
var game_started: bool = false
var current_day: int = 1
var current_time: float = 8.0  # 8:00 AM in hours
var time_scale: float = 1.0  # How fast time progresses

# Player resources
var player_gold: int = 0
var player_essence: int = 0
var player_experience: int = 0
var player_level: int = 1
var experience_to_next_level: int = 100

# Workshop state
var unlocked_stations: Array = ["cauldron"]  # Start with just the cauldron
var station_levels: Dictionary = {
	"cauldron": 1,
	"distillery": 1,
	"herb_station": 1,
	"study_table": 1
}

# Shop and other systems state
var shop_unlocked: bool = false  # Fixed property

# Specializations (0-20 scale)
var specializations: Dictionary = {
	"healing": 0,
	"utility": 0,
	"transformation": 0,
	"mind": 0
}

# Constructor
func _init():
	# Initialize any runtime variables here
	pass

# Called when the node enters the scene tree
func _ready():
	# Initialize time handling
	var timer = Timer.new()
	timer.wait_time = 5.0  # Check every 5 seconds
	timer.autostart = true
	timer.timeout.connect(_update_game_time)
	add_child(timer)
	
	# Connect to signals from other systems using deferred connections
	call_deferred("_connect_systems")
	
	# Debug: Print that GameManager is ready
	print("GameManager initialized")

# Process for updating time-based systems
func _process(delta):
	if game_started:
		# Update game time
		current_time += delta * time_scale / 300.0  # 1 real second = 12 in-game seconds (5 min per real hour)
		
		# Handle day change
		if current_time >= 24.0:
			current_time -= 24.0
			current_day += 1
			game_day_passed.emit(current_day)

# Public methods
func start_new_game():
	"""Starts a new game with default values"""
	# Reset game state
	game_started = true
	current_day = 1
	current_time = 8.0
	
	# Reset player resources
	player_gold = 10
	player_essence = 0
	player_experience = 0
	player_level = 1
	experience_to_next_level = 100
	
	# Reset workshop
	unlocked_stations = ["cauldron"]
	station_levels = {
		"cauldron": 1,
		"distillery": 1,
		"herb_station": 1,
		"study_table": 1
	}
	
	# Reset other systems
	shop_unlocked = false
	
	# Reset specializations
	specializations = {
		"healing": 0,
		"utility": 0,
		"transformation": 0,
		"mind": 0
	}
	
	# Initialize other systems
	_initialize_systems()
	
	# Signal that a new game has started
	game_initialized.emit()
	
	return true

func load_game(save_data = null):
	"""Loads game from save data or default if null"""
	# If no save data, start a new game
	if save_data == null:
		return start_new_game()
	
	# TODO: Implement proper save loading
	game_started = true
	
	# Signal that game was loaded
	game_loaded.emit()
	
	return true

func save_game():
	"""Saves the current game state"""
	# TODO: Implement proper save system
	var save_data = {
		"current_day": current_day,
		"current_time": current_time,
		"player_gold": player_gold,
		"player_essence": player_essence,
		"player_experience": player_experience,
		"player_level": player_level,
		"unlocked_stations": unlocked_stations,
		"station_levels": station_levels,
		"specializations": specializations,
		"shop_unlocked": shop_unlocked
	}
	
	# Signal that game was saved
	game_saved.emit()
	
	return save_data

# Resource management
func add_gold(amount):
	"""Adds gold to the player's inventory"""
	player_gold += amount
	gold_changed.emit(player_gold)
	return player_gold

func remove_gold(amount):
	"""Removes gold from the player's inventory if possible"""
	if player_gold >= amount:
		player_gold -= amount
		gold_changed.emit(player_gold)
		return true
	return false

func add_essence(amount):
	"""Adds essence to the player's inventory"""
	player_essence += amount
	essence_changed.emit(player_essence)
	return player_essence

func remove_essence(amount):
	"""Removes essence from the player's inventory if possible"""
	if player_essence >= amount:
		player_essence -= amount
		essence_changed.emit(player_essence)
		return true
	return false

func add_experience(amount):
	"""Adds experience and handles leveling up"""
	player_experience += amount
	experience_gained.emit(amount)
	
	# Check for level up
	if player_experience >= experience_to_next_level:
		player_experience -= experience_to_next_level
		player_level += 1
		experience_to_next_level = _calculate_next_level_exp(player_level)
		level_up.emit(player_level)
	
	return player_experience

# Workshop management
func unlock_station(station_name):
	"""Unlocks a new workshop station"""
	if station_name in unlocked_stations:
		return false
	
	unlocked_stations.append(station_name)
	return true

func upgrade_station(station_name):
	"""Upgrades a workshop station level"""
	if not (station_name in station_levels):
		return false
	
	station_levels[station_name] += 1
	return true

# Shop management
func unlock_shop():
	"""Unlocks the shop for the player"""
	if shop_unlocked:
		return false
	
	shop_unlocked = true
	return true

# Private methods
func _connect_systems():
	"""Connects to other autoloaded systems"""
	# Use get_node_or_null to safely get references when needed
	var inventory_system = get_node_or_null("/root/InventoryManager")
	if inventory_system and inventory_system.has_signal("inventory_full"):
		inventory_system.inventory_full.connect(_on_inventory_full)

func _initialize_systems():
	"""Initialize other game systems when starting a new game"""
	# Initialize gathering system
	var gathering_system = get_node_or_null("/root/GatheringSystem")
	if gathering_system and gathering_system.has_method("refresh_daily_resources"):
		gathering_system.refresh_daily_resources()
	
	# Initialize weather system
	var weather_system = get_node_or_null("/root/WeatherSystem")
	if weather_system and weather_system.has_method("initialize_weather"):
		weather_system.initialize_weather()
	
	# Initialize any other systems that need starting state
	# - Important: DON'T store references, just call methods

func _update_game_time():
	"""Regular update for time-based systems"""
	if not game_started:
		return
	
	# Update gathering system if it exists
	var gathering_system = get_node_or_null("/root/GatheringSystem")
	if gathering_system and gathering_system.has_method("update_resources"):
		gathering_system.update_resources()
	
	# Update weather system if it exists
	var weather_system = get_node_or_null("/root/WeatherSystem") 
	if weather_system and weather_system.has_method("update_weather"):
		weather_system.update_weather(current_time)
		
	# Update villager orders if needed
	var villager_order_system = get_node_or_null("/root/VillagerOrderSystem")
	if villager_order_system and villager_order_system.has_method("update_orders"):
		villager_order_system.update_orders()

func _calculate_next_level_exp(level):
	"""Calculates experience needed for the next level"""
	# Simple formula: base 100 + 50 per level
	return 100 + (level * 50)

func _on_inventory_full():
	"""Handler for inventory full signal"""
	# Use get_node_or_null instead of storing references to avoid invalid assignments
	var notification_system = get_node_or_null("/root/NotificationSystem")
	if notification_system and notification_system.has_method("show_warning"):
		notification_system.show_warning("Inventory is full!")
	else:
		print("Inventory is full!") # Fallback when notification system not available
