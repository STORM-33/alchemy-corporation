extends Node
## Manages villager NPCs, their relationships, and orders
## Add this script to an autoload in the Project Settings

# Signals
signal order_placed(order_id, villager_id, item_id)
signal order_completed(order_id, villager_id)
signal order_failed(order_id, villager_id)
signal relationship_changed(villager_id, new_level)
signal villager_unlocked(villager_id)

# Constants
const BASE_ORDER_CHANCE = 0.3  # Base daily chance of a villager placing an order
const RELATIONSHIP_LEVELS = ["Stranger", "Acquaintance", "Friend", "Trusted", "Devoted"]
const MAX_ACTIVE_ORDERS_PER_VILLAGER = 2  # Maximum number of active orders per villager
const MIN_ORDER_EXPIRY = 1440  # Minimum order time limit (24 hours in minutes)
const MAX_ORDER_EXPIRY = 4320  # Maximum order time limit (72 hours in minutes)

# Villager data
var _villagers = {}  # Dictionary of villager_id: villager data
var _active_orders = {}  # Dictionary of order_id: order data
var _completed_orders = []  # Array of completed order IDs
var _villager_relationships = {}  # Dictionary of villager_id: relationship level (0-4)

# Private variables
var _day_timer = null  # Timer for checking orders once per game day
var _current_game_day = 1

# Lifecycle methods
func _ready():
	# Load villager data
	_load_villagers()
	
	# Register with GameManager
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.villager_manager = self
		game_manager.game_day_passed.connect(_on_game_day_passed)
		_current_game_day = game_manager.current_game_day

# Public methods
func get_villager(villager_id):
	"""Returns data for the specified villager"""
	if _villagers.has(villager_id):
		return _villagers[villager_id]
	return null

func get_all_villagers():
	"""Returns all villager data"""
	return _villagers.duplicate(true)

func get_unlocked_villagers():
	"""Returns all unlocked villager data"""
	var unlocked = {}
	for villager_id in _villagers:
		if _villagers[villager_id].unlocked:
			unlocked[villager_id] = _villagers[villager_id]
	return unlocked

func get_relationship_level(villager_id):
	"""Gets the relationship level with a villager"""
	if not _villager_relationships.has(villager_id):
		return 0
	return _villager_relationships[villager_id]

func get_relationship_name(villager_id):
	"""Gets the relationship level name with a villager"""
	var level = get_relationship_level(villager_id)
	return RELATIONSHIP_LEVELS[level]

func get_active_orders():
	"""Returns all active orders"""
	return _active_orders.duplicate(true)

func get_active_orders_for_villager(villager_id):
	"""Returns all active orders for a specific villager"""
	var orders = {}
	for order_id in _active_orders:
		if _active_orders[order_id].villager_id == villager_id:
			orders[order_id] = _active_orders[order_id]
	return orders

func get_completed_orders():
	"""Returns IDs of all completed orders"""
	return _completed_orders.duplicate()

func place_order(villager_id, item_id, quantity=1, time_limit=1440):
	"""
	Places a new order from a villager
	Returns the order ID if successful, or empty string if failed
	"""
	if not _villagers.has(villager_id) or not _villagers[villager_id].unlocked:
		return ""
	
	# Check if villager already has maximum orders
	var villager_orders = get_active_orders_for_villager(villager_id)
	if villager_orders.size() >= MAX_ACTIVE_ORDERS_PER_VILLAGER:
		return ""
	
	# Generate order ID
	var order_id = "order_" + villager_id + "_" + str(Time.get_unix_time_from_system())
	
	# Calculate reward based on item, quantity, and relationship
	var reward = _calculate_order_reward(villager_id, item_id, quantity)
	
	# Create order data
	var order = {
		"id": order_id,
		"villager_id": villager_id,
		"item_id": item_id,
		"quantity": quantity,
		"fulfilled": 0,
		"created_day": _current_game_day,
		"time_limit": time_limit,
		"time_remaining": time_limit,
		"reward": reward,
		"completed": false,
		"failed": false
	}
	
	# Add to active orders
	_active_orders[order_id] = order
	
	# Signal that order was placed
	order_placed.emit(order_id, villager_id, item_id)
	
	return order_id

func fulfill_order(order_id, quantity=1):
	"""
	Adds quantity to an order's fulfillment
	Returns true if order is now complete
	"""
	if not _active_orders.has(order_id):
		return false
	
	var order = _active_orders[order_id]
	if order.completed or order.failed:
		return false
	
	# Add to fulfilled amount
	order.fulfilled += quantity
	
	# Check if order is now complete
	if order.fulfilled >= order.quantity:
		return _complete_order(order_id)
	
	return false

func _complete_order(order_id):
	"""
	Marks an order as complete and awards rewards
	Returns true if successful
	"""
	if not _active_orders.has(order_id):
		return false
	
	var order = _active_orders[order_id]
	if order.completed or order.failed:
		return false
	
	var villager_id = order.villager_id
	var reward = order.reward
	
	# Mark as complete
	order.completed = true
	_completed_orders.append(order_id)
	
	# Award rewards
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		if reward.has("gold"):
			game_manager.add_gold(reward.gold)
		if reward.has("essence"):
			game_manager.add_essence(reward.essence)
		if reward.has("experience"):
			# Handle player experience
			pass
	
	# Improve relationship
	_increase_relationship(villager_id, 1 + int(order.quantity / 2))
	
	# Signal completion
	order_completed.emit(order_id, villager_id)
	
	return true

func fail_order(order_id):
	"""
	Marks an order as failed
	Returns true if successful
	"""
	if not _active_orders.has(order_id):
		return false
	
	var order = _active_orders[order_id]
	if order.completed or order.failed:
		return false
	
	var villager_id = order.villager_id
	
	# Mark as failed
	order.failed = true
	
	# Decrease relationship
	_decrease_relationship(villager_id, 1)
	
	# Signal failure
	order_failed.emit(order_id, villager_id)
	
	return true

func unlock_villager(villager_id):
	"""
	Unlocks a villager for interactions
	Returns true if successful
	"""
	if not _villagers.has(villager_id) or _villagers[villager_id].unlocked:
		return false
	
	_villagers[villager_id].unlocked = true
	
	# Initialize relationship if needed
	if not _villager_relationships.has(villager_id):
		_villager_relationships[villager_id] = 0
	
	# Signal that villager was unlocked
	villager_unlocked.emit(villager_id)
	
	return true

func get_save_data():
	"""Returns a dictionary with all data needed to save villager state"""
	return {
		"villager_relationships": _villager_relationships,
		"active_orders": _active_orders,
		"completed_orders": _completed_orders,
		"unlocked_villagers": get_unlocked_villagers().keys()
	}

func load_save_data(data):
	"""Loads villager state from saved data"""
	if data.has("villager_relationships"):
		_villager_relationships = data.villager_relationships.duplicate(true)
	
	if data.has("active_orders"):
		_active_orders = data.active_orders.duplicate(true)
	
	if data.has("completed_orders"):
		_completed_orders = data.completed_orders.duplicate()
	
	if data.has("unlocked_villagers"):
		for villager_id in data.unlocked_villagers:
			if _villagers.has(villager_id):
				_villagers[villager_id].unlocked = true

func refresh_daily_orders():
	"""Generates new orders and updates existing ones"""
	_update_order_timers()
	_generate_new_orders()

# Private methods
func _load_villagers():
	"""Loads all villager data"""
	# Clear existing data
	_villagers.clear()
	
	# Create default villagers
	_create_default_villagers()
	
	# Initialize relationships for unlocked villagers
	for villager_id in _villagers:
		if _villagers[villager_id].unlocked and not _villager_relationships.has(villager_id):
			_villager_relationships[villager_id] = 0

func _create_default_villagers():
	"""Creates default villager data"""
	# Farmer Giles
	_villagers["farmer_giles"] = {
		"id": "farmer_giles",
		"name": "Farmer Giles",
		"description": "A hardworking farmer with crop troubles and family responsibilities.",
		"unlocked": true,  # Available from start
		"portrait": "res://assets/images/villagers/farmer_giles.png",
		"preferred_items": ["pot_minor_healing", "pot_growth_tonic"],
		"disliked_items": [],
		"order_categories": ["healing", "transformation"],
		"order_chance": 0.4
	}
	
	# Blacksmith Hilda
	_villagers["blacksmith_hilda"] = {
		"id": "blacksmith_hilda",
		"name": "Blacksmith Hilda",
		"description": "A skilled blacksmith seeking cooling solutions for her forge.",
		"unlocked": true,  # Available from start
		"portrait": "res://assets/images/villagers/blacksmith_hilda.png",
		"preferred_items": ["pot_cooling_salve", "pot_metal_treatment"],
		"disliked_items": ["pot_freezing_solution"],
		"order_categories": ["healing", "utility"],
		"order_chance": 0.3
	}
	
	# Guard Captain Marcus
	_villagers["guard_marcus"] = {
		"id": "guard_marcus",
		"name": "Guard Captain Marcus",
		"description": "The village guard captain who suffers from an old wound.",
		"unlocked": false,  # Unlock through progression
		"portrait": "res://assets/images/villagers/guard_marcus.png",
		"preferred_items": ["pot_minor_healing", "pot_strength_tonic"],
		"disliked_items": ["pot_sleeping_draught"],
		"order_categories": ["healing", "transformation"],
		"order_chance": 0.3
	}
	
	# Herbalist Willow
	_villagers["herbalist_willow"] = {
		"id": "herbalist_willow",
		"name": "Herbalist Willow",
		"description": "A fellow herbalist who can teach you new recipes.",
		"unlocked": false,  # Unlock through progression
		"portrait": "res://assets/images/villagers/herbalist_willow.png",
		"preferred_items": ["pot_clarity", "pot_preservation_fluid"],
		"disliked_items": [],
		"order_categories": ["mind", "utility"],
		"order_chance": 0.25
	}
	
	# Add more villagers as needed

func _increase_relationship(villager_id, amount=1):
	"""Increases relationship with a villager"""
	if not _villager_relationships.has(villager_id):
		_villager_relationships[villager_id] = 0
	
	var old_level = _villager_relationships[villager_id]
	var new_level = min(old_level + amount, RELATIONSHIP_LEVELS.size() - 1)
	
	if new_level != old_level:
		_villager_relationships[villager_id] = new_level
		relationship_changed.emit(villager_id, new_level)
		
		# Show notification about improved relationship
		var notification_system = get_node_or_null("/root/NotificationSystem")
		if notification_system:
			var villager_name = _villagers[villager_id].name
			var relationship_name = RELATIONSHIP_LEVELS[new_level]
			notification_system.show_success(villager_name + " now considers you a " + relationship_name + "!")

func _decrease_relationship(villager_id, amount=1):
	"""Decreases relationship with a villager"""
	if not _villager_relationships.has(villager_id):
		_villager_relationships[villager_id] = 0
	
	var old_level = _villager_relationships[villager_id]
	var new_level = max(old_level - amount, 0)
	
	if new_level != old_level:
		_villager_relationships[villager_id] = new_level
		relationship_changed.emit(villager_id, new_level)
		
		# Show notification about worsened relationship
		var notification_system = get_node_or_null("/root/NotificationSystem")
		if notification_system:
			var villager_name = _villagers[villager_id].name
			var relationship_name = RELATIONSHIP_LEVELS[new_level]
			notification_system.show_warning("Your relationship with " + villager_name + " has decreased to " + relationship_name + ".")

func _calculate_order_reward(villager_id, item_id, quantity):
	"""Calculates the reward for an order based on item, quantity, and relationship"""
	var reward = {"gold": 0, "essence": 0}
	
	# Get base value of the item
	var base_value = _get_item_base_value(item_id)
	if base_value <= 0:
		base_value = 5  # Default value if unknown
	
	# Calculate gold reward
	reward.gold = base_value * quantity * 1.5  # 50% markup
	
	# Add relationship bonus (up to 50% more at max relationship)
	var relationship_level = get_relationship_level(villager_id)
	var relationship_bonus = 1.0 + (relationship_level * 0.125)  # 12.5% per level
	reward.gold = int(reward.gold * relationship_bonus)
	
	# Add essence for higher value items and higher quantities
	if base_value >= 8 or quantity >= 3:
		reward.essence = 1
	
	if base_value >= 15 or quantity >= 5:
		reward.essence = 2
	
	return reward

func _get_item_base_value(item_id):
	"""Gets the base value of an item"""
	if item_id.begins_with("pot_"):
		var recipe_manager = get_node_or_null("/root/RecipeManager")
		if recipe_manager:
			var potion = recipe_manager.get_potion(item_id)
			if potion:
				return potion.base_value
	elif item_id.begins_with("ing_"):
		var ingredient_manager = get_node_or_null("/root/IngredientManager")
		if ingredient_manager:
			var ingredient = ingredient_manager.get_ingredient(item_id)
			if ingredient:
				return ingredient.base_value
	
	return 0

func _update_order_timers():
	"""Updates timers for all active orders"""
	var orders_to_fail = []
	
	for order_id in _active_orders:
		var order = _active_orders[order_id]
		if not order.completed and not order.failed:
			# Reduce time remaining
			order.time_remaining -= 1440  # One day in minutes
			
			# Check if order has expired
			if order.time_remaining <= 0:
				orders_to_fail.append(order_id)
	
	# Fail expired orders
	for order_id in orders_to_fail:
		fail_order(order_id)

func _generate_new_orders():
	"""Generates new orders from villagers"""
	var recipe_manager = get_node_or_null("/root/RecipeManager")
	if not recipe_manager:
		return
	
	for villager_id in _villagers:
		var villager = _villagers[villager_id]
		if not villager.unlocked:
			continue
		
		# Check if villager will place an order today
		var order_chance = BASE_ORDER_CHANCE
		if villager.has("order_chance"):
			order_chance = villager.order_chance
		
		# Increase chance based on relationship
		var relationship_level = get_relationship_level(villager_id)
		order_chance += relationship_level * 0.1  # +10% per level
		
		if randf() > order_chance:
			continue
		
		# Check if villager has room for more orders
		var villager_orders = get_active_orders_for_villager(villager_id)
		if villager_orders.size() >= MAX_ACTIVE_ORDERS_PER_VILLAGER:
			continue
		
		# Determine what item to order
		var item_id = _choose_order_item(villager)
		if item_id.empty():
			continue
		
		# Determine quantity based on relationship
		var base_quantity = 1
		var max_quantity = 1 + relationship_level
		var quantity = randi_range(base_quantity, max_quantity)
		
		# Determine time limit
		var time_limit = randi_range(MIN_ORDER_EXPIRY, MAX_ORDER_EXPIRY)
		
		# Place the order
		place_order(villager_id, item_id, quantity, time_limit)

func _choose_order_item(villager):
	"""Chooses an item for a villager to order"""
	var recipe_manager = get_node_or_null("/root/RecipeManager")
	if not recipe_manager:
		return ""
	
	var possible_items = []
	
	# Add preferred items with higher weight
	for item_id in villager.preferred_items:
		if _is_potion_discovered(item_id):
			possible_items.append(item_id)
			possible_items.append(item_id)  # Add twice for higher probability
	
	# Add potions from preferred categories
	if villager.has("order_categories"):
		for category in villager.order_categories:
			var category_recipes = recipe_manager.get_recipes_by_category(category)
			for recipe_id in category_recipes:
				var recipe = recipe_manager.get_recipe(recipe_id)
				if recipe and recipe.discovered:
					var result_id = recipe.result_id
					if not villager.disliked_items.has(result_id):
						possible_items.append(result_id)
	
	# Choose random item from possibilities
	if possible_items.empty():
		return ""
	
	var random_index = randi() % possible_items.size()
	return possible_items[random_index]

func _is_potion_discovered(potion_id):
	"""Checks if a potion recipe has been discovered"""
	var recipe_manager = get_node_or_null("/root/RecipeManager")
	if not recipe_manager:
		return false
	
	# Check if any recipe with this result is discovered
	for recipe_id in recipe_manager.get_all_recipe_ids():
		var recipe = recipe_manager.get_recipe(recipe_id)
		if recipe and recipe.result_id == potion_id and recipe.discovered:
			return true
	
	return false

func _on_game_day_passed(day_number):
	"""Called when a game day passes"""
	_current_game_day = day_number
	refresh_daily_orders()
