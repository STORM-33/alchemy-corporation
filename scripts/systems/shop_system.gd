extends Node
## Shop system for purchasing ingredients, upgrades, and recipes
## Add this script to an autoload in the Project Settings

# Signals
signal shop_inventory_updated
signal item_purchased(item_id, price)
signal recipe_purchased(recipe_id, price)
signal upgrade_purchased(upgrade_id, price)

# Constants
const BASE_RESTOCK_PERIOD = 1  # Restock every X game days
const MAX_SHOP_ITEMS = 10  # Maximum items in shop at once
const RARITY_PRICE_MULTIPLIER = {
	1: 2.0,  # Common ingredients cost 2x base value
	2: 2.5,  # Uncommon ingredients cost 2.5x base value
	3: 3.0,  # Rare ingredients cost 3x base value
	4: 4.0,  # Very rare ingredients cost 4x base value
	5: 5.0   # Legendary ingredients cost 5x base value
}

# Shop inventory
var _shop_inventory = {}  # Dictionary of item_id: {quantity, price, type, etc.}
var _available_recipes = {}  # Dictionary of recipe_id: {price, unlocked}
var _available_upgrades = {}  # Dictionary of upgrade_id: {price, unlocked, requirements}

# Shop state
var _last_restock_day = 0
var _shop_level = 1

# Lifecycle methods
func _ready():
	# Connect to game systems
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.game_day_passed.connect(_on_game_day_passed)
		game_manager.shop_unlocked.connect(_on_shop_unlocked)
		_last_restock_day = game_manager.current_game_day
	
	# Initialize available upgrades
	_initialize_shop_upgrades()
	
	# Initialize available recipes
	_initialize_shop_recipes()

# Public methods
func get_shop_inventory():
	"""Returns the current shop inventory"""
	return _shop_inventory.duplicate(true)

func get_available_recipes():
	"""Returns recipes available for purchase"""
	return _available_recipes.duplicate(true)

func get_available_upgrades():
	"""Returns upgrades available for purchase"""
	return _available_upgrades.duplicate(true)

func purchase_item(item_id, quantity=1):
	"""
	Attempts to purchase an item from the shop
	Returns a success dictionary with status and message
	"""
	# Check if item exists in shop
	if not _shop_inventory.has(item_id):
		return {"success": false, "message": "Item not available in shop"}
	
	var item = _shop_inventory[item_id]
	
	# Check if enough quantity is available
	if item.quantity < quantity:
		return {"success": false, "message": "Not enough stock available"}
	
	# Calculate total price
	var total_price = item.price * quantity
	
	# Check if player has enough gold
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager or game_manager.player_gold < total_price:
		return {"success": false, "message": "Not enough gold"}
	
	# Process purchase
	game_manager.spend_gold(total_price)
	item.quantity -= quantity
	
	# If quantity is now 0, remove from inventory
	if item.quantity <= 0:
		_shop_inventory.erase(item_id)
	
	# Add to player inventory
	var inventory_manager = get_node_or_null("/root/InventoryManager")
	if inventory_manager:
		inventory_manager.add_item(item_id, quantity, item.quality)
	
	# Emit signal
	item_purchased.emit(item_id, total_price)
	shop_inventory_updated.emit()
	
	return {"success": true, "message": "Purchase successful"}

func purchase_recipe(recipe_id):
	"""
	Attempts to purchase a recipe from the shop
	Returns a success dictionary with status and message
	"""
	# Check if recipe exists and is not already unlocked
	if not _available_recipes.has(recipe_id) or _available_recipes[recipe_id].unlocked:
		return {"success": false, "message": "Recipe not available for purchase"}
	
	var recipe = _available_recipes[recipe_id]
	
	# Check if player has enough gold
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager or game_manager.player_gold < recipe.price:
		return {"success": false, "message": "Not enough gold"}
	
	# Process purchase
	game_manager.spend_gold(recipe.price)
	recipe.unlocked = true
	
	# Discover the recipe
	var recipe_manager = get_node_or_null("/root/RecipeManager")
	if recipe_manager:
		recipe_manager.discover_recipe(recipe_id)
	
	# Emit signal
	recipe_purchased.emit(recipe_id, recipe.price)
	
	return {"success": true, "message": "Recipe purchased successfully"}

func purchase_upgrade(upgrade_id):
	"""
	Attempts to purchase an upgrade from the shop
	Returns a success dictionary with status and message
	"""
	# Check if upgrade exists and is not already unlocked
	if not _available_upgrades.has(upgrade_id) or _available_upgrades[upgrade_id].unlocked:
		return {"success": false, "message": "Upgrade not available for purchase"}
	
	var upgrade = _available_upgrades[upgrade_id]
	
	# Check requirements
	if not _check_upgrade_requirements(upgrade_id):
		return {"success": false, "message": "Requirements not met"}
	
	# Check if player has enough gold
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager or game_manager.player_gold < upgrade.price:
		return {"success": false, "message": "Not enough gold"}
	
	# Process purchase
	game_manager.spend_gold(upgrade.price)
	upgrade.unlocked = true
	
	# Apply upgrade effects
	_apply_upgrade_effects(upgrade_id)
	
	# Emit signal
	upgrade_purchased.emit(upgrade_id, upgrade.price)
	
	return {"success": true, "message": "Upgrade purchased successfully"}

func restock_shop():
	"""Restocks the shop with new items"""
	# Clear current inventory (except for always-available items)
	var permanent_items = {}
	for item_id in _shop_inventory:
		if _shop_inventory[item_id].permanent:
			permanent_items[item_id] = _shop_inventory[item_id]
	
	_shop_inventory = permanent_items
	
	# Add new random items
	_add_random_ingredients()
	
	# Update the last restock day
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		_last_restock_day = game_manager.current_game_day
	
	# Signal update
	shop_inventory_updated.emit()

func upgrade_shop_level():
	"""
	Upgrades the shop level
	Returns success status
	"""
	if _shop_level >= 3:  # Max level
		return false
	
	_shop_level += 1
	
	# Restock with potentially better items
	restock_shop()
	
	return true

func get_save_data():
	"""Returns a dictionary with shop state for saving"""
	return {
		"shop_inventory": _shop_inventory,
		"available_recipes": _available_recipes,
		"available_upgrades": _available_upgrades,
		"last_restock_day": _last_restock_day,
		"shop_level": _shop_level
	}

func load_save_data(data):
	"""Loads shop state from saved data"""
	if data.has("shop_inventory"):
		_shop_inventory = data.shop_inventory.duplicate(true)
	
	if data.has("available_recipes"):
		_available_recipes = data.available_recipes.duplicate(true)
	
	if data.has("available_upgrades"):
		_available_upgrades = data.available_upgrades.duplicate(true)
	
	if data.has("last_restock_day"):
		_last_restock_day = data.last_restock_day
	
	if data.has("shop_level"):
		_shop_level = data.shop_level

# Private methods
func _initialize_shop_upgrades():
	"""Sets up the available shop upgrades"""
	# Workshop upgrade - Cauldron
	_available_upgrades["upgrade_cauldron_2"] = {
		"id": "upgrade_cauldron_2",
		"name": "Cauldron Enhancement",
		"description": "Upgrade your cauldron to brew potions 20% faster",
		"price": 200,
		"unlocked": false,
		"requirements": {
			"player_level": 3
		},
		"effects": {
			"station_level": {"cauldron": 2}
		}
	}
	
	_available_upgrades["upgrade_cauldron_3"] = {
		"id": "upgrade_cauldron_3",
		"name": "Master Cauldron",
		"description": "Upgrade to a master cauldron for 30% faster brewing and 10% quality bonus",
		"price": 500,
		"unlocked": false,
		"requirements": {
			"player_level": 7,
			"upgrades": ["upgrade_cauldron_2"]
		},
		"effects": {
			"station_level": {"cauldron": 3}
		}
	}
	
	# Herb Station upgrades
	_available_upgrades["upgrade_herb_station_2"] = {
		"id": "upgrade_herb_station_2",
		"name": "Herb Processor",
		"description": "Upgrade your herb station to process ingredients 25% more efficiently",
		"price": 250,
		"unlocked": false,
		"requirements": {
			"player_level": 5,
			"stations": ["herb_station"]
		},
		"effects": {
			"station_level": {"herb_station": 2}
		}
	}
	
	# Distillery upgrades
	_available_upgrades["upgrade_distillery_2"] = {
		"id": "upgrade_distillery_2",
		"name": "Advanced Distillery",
		"description": "Upgrade your distillery for 20% higher essence yield",
		"price": 350,
		"unlocked": false,
		"requirements": {
			"player_level": 6,
			"stations": ["distillery"]
		},
		"effects": {
			"station_level": {"distillery": 2}
		}
	}
	
	# Garden upgrades
	_available_upgrades["upgrade_garden_plots"] = {
		"id": "upgrade_garden_plots",
		"name": "Expanded Garden",
		"description": "Expand your garden with 3 additional growing plots",
		"price": 150,
		"unlocked": false,
		"requirements": {
			"player_level": 4
		},
		"effects": {
			"garden_plots": 3
		}
	}
	
	# Inventory upgrades
	_available_upgrades["upgrade_inventory_1"] = {
		"id": "upgrade_inventory_1",
		"name": "Expanded Storage",
		"description": "Increase your inventory capacity by 5 slots",
		"price": 100,
		"unlocked": false,
		"requirements": {
			"player_level": 2
		},
		"effects": {
			"inventory_upgrade": 1
		}
	}
	
	_available_upgrades["upgrade_inventory_2"] = {
		"id": "upgrade_inventory_2",
		"name": "Storage Shelves",
		"description": "Increase your inventory capacity by 5 more slots",
		"price": 250,
		"unlocked": false,
		"requirements": {
			"player_level": 5,
			"upgrades": ["upgrade_inventory_1"]
		},
		"effects": {
			"inventory_upgrade": 1
		}
	}

func _initialize_shop_recipes():
	"""Sets up the available shop recipes"""
	var recipe_manager = get_node_or_null("/root/RecipeManager")
	if not recipe_manager:
		return
	
	# Get all recipes
	var all_recipes = {}
	for recipe_id in recipe_manager.get_all_recipe_ids():
		var recipe = recipe_manager.get_recipe(recipe_id)
		if recipe:
			all_recipes[recipe_id] = recipe
	
	# Add selected recipes to shop
	for recipe_id in all_recipes:
		var recipe = all_recipes[recipe_id]
		
		# Skip already discovered recipes
		if recipe.discovered:
			continue
		
		# Calculate price based on difficulty and result value
		var base_price = 50
		if recipe.difficulty > 1:
			base_price = 50 * recipe.difficulty
		
		_available_recipes[recipe_id] = {
			"id": recipe_id,
			"name": recipe.name,
			"description": recipe.description,
			"category": recipe.category,
			"price": base_price,
			"unlocked": false
		}

func _check_upgrade_requirements(upgrade_id):
	"""Checks if requirements for an upgrade are met"""
	if not _available_upgrades.has(upgrade_id):
		return false
	
	var upgrade = _available_upgrades[upgrade_id]
	if not upgrade.has("requirements"):
		return true
	
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return false
	
	# Check player level
	if upgrade.requirements.has("player_level") and game_manager.player_level < upgrade.requirements.player_level:
		return false
	
	# Check required stations
	if upgrade.requirements.has("stations"):
		for station in upgrade.requirements.stations:
			if not game_manager.unlocked_stations.has(station):
				return false
	
	# Check required upgrades
	if upgrade.requirements.has("upgrades"):
		for req_upgrade in upgrade.requirements.upgrades:
			if not _available_upgrades.has(req_upgrade) or not _available_upgrades[req_upgrade].unlocked:
				return false
	
	return true

func _apply_upgrade_effects(upgrade_id):
	"""Applies the effects of an upgrade"""
	if not _available_upgrades.has(upgrade_id):
		return
	
	var upgrade = _available_upgrades[upgrade_id]
	if not upgrade.has("effects"):
		return
	
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return
	
	# Apply station level upgrades
	if upgrade.effects.has("station_level"):
		for station in upgrade.effects.station_level:
			game_manager.station_levels[station] = upgrade.effects.station_level[station]
	
	# Apply inventory upgrades
	if upgrade.effects.has("inventory_upgrade"):
		var inventory_manager = get_node_or_null("/root/InventoryManager")
		if inventory_manager:
			inventory_manager.upgrade_inventory()
	
	# Apply garden plot upgrades
	if upgrade.effects.has("garden_plots"):
		var gathering_system = get_node_or_null("/root/GatheringSystem")
		if gathering_system:
			gathering_system.add_garden_plots(upgrade.effects.garden_plots)

func _add_random_ingredients():
	"""Adds random ingredients to the shop inventory"""
	var ingredient_manager = get_node_or_null("/root/IngredientManager")
	if not ingredient_manager:
		return
	
	var all_ingredients = ingredient_manager.get_all_ingredient_ids()
	if all_ingredients.empty():
		return
	
	# Determine how many items to add
	var base_items = 3 + _shop_level
	var item_count = min(base_items, MAX_SHOP_ITEMS - _shop_inventory.size())
	
	# Add random items
	var added_items = []
	while added_items.size() < item_count and all_ingredients.size() > 0:
		# Pick a random ingredient
		var index = randi() % all_ingredients.size()
		var ingredient_id = all_ingredients[index]
		
		# Skip if already in inventory
		if _shop_inventory.has(ingredient_id):
			all_ingredients.remove_at(index)
			continue
		
		# Get ingredient data
		var ingredient = ingredient_manager.get_ingredient(ingredient_id)
		if not ingredient:
			all_ingredients.remove_at(index)
			continue
		
		# Calculate price based on rarity
		var base_price = ingredient.base_value
		var rarity = min(max(ingredient.rarity, 1), 5)
		var price_multiplier = RARITY_PRICE_MULTIPLIER[rarity]
		var price = int(base_price * price_multiplier)
		
		# Higher shop level means more stock of rare items
		var max_quantity = 5
		if ingredient.rarity > 2:
			max_quantity = 2 + _shop_level
		
		var quantity = randi_range(1, max_quantity)
		
		# Add to shop inventory
		_shop_inventory[ingredient_id] = {
			"id": ingredient_id,
			"name": ingredient.name,
			"description": ingredient.description,
			"type": "ingredient",
			"category": ingredient.category,
			"price": price,
			"quantity": quantity,
			"quality": 1.0,
			"permanent": false
		}
		
		added_items.append(ingredient_id)
		all_ingredients.remove_at(index)
	
	# Always add some Pure Water (a basic necessity)
	if not _shop_inventory.has("ing_pure_water"):
		var pure_water = ingredient_manager.get_ingredient("ing_pure_water")
		if pure_water:
			_shop_inventory["ing_pure_water"] = {
				"id": "ing_pure_water",
				"name": pure_water.name,
				"description": pure_water.description,
				"type": "ingredient",
				"category": pure_water.category,
				"price": 8,
				"quantity": 10,
				"quality": 1.0,
				"permanent": true  # Always available
			}

# Signal handlers
func _on_game_day_passed(day_number):
	"""Called when a game day passes"""
	# Check if it's time to restock
	var days_since_restock = day_number - _last_restock_day
	if days_since_restock >= BASE_RESTOCK_PERIOD:
		restock_shop()

func _on_shop_unlocked():
	"""Called when the shop is unlocked"""
	restock_shop()
