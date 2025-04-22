extends Node
## Inventory system for storing and managing player items

# Signals
signal inventory_updated(item_id, new_quantity)
signal item_added(item_id, quantity)
signal item_removed(item_id, quantity)
signal inventory_full

# Private variables
var _inventory = {}  # Dictionary mapping item_id to {quantity, quality}
var _inventory_size = 20  # Maximum number of different items

# Called when the node enters the scene tree for the first time
func _ready():
	# Initialize empty inventory
	pass

# Public methods
func add_item(item_id: String, quantity: int = 1, quality: float = 1.0):
	"""Adds an item to the inventory"""
	if _is_inventory_full() and not has_item(item_id):
		# Inventory is full and this is a new item
		inventory_full.emit()
		return false
	
	if has_item(item_id):
		# Update existing item
		_inventory[item_id].quantity += quantity
		
		# Average the quality if adding multiple of existing item
		if quantity > 0:
			var old_quality = _inventory[item_id].quality
			var old_quantity = _inventory[item_id].quantity - quantity
			var new_total = old_quantity + quantity
			_inventory[item_id].quality = (old_quality * old_quantity + quality * quantity) / new_total
	else:
		# Add new item
		_inventory[item_id] = {
			"quantity": quantity,
			"quality": quality
		}
	
	# Emit signals
	item_added.emit(item_id, quantity)
	inventory_updated.emit(item_id, _inventory[item_id].quantity)
	
	return true

func remove_item(item_id: String, quantity: int = 1):
	"""Removes an item from the inventory"""
	if not has_item(item_id, quantity):
		return false
	
	_inventory[item_id].quantity -= quantity
	
	if _inventory[item_id].quantity <= 0:
		# Remove item entirely if quantity is now 0
		var old_quantity = _inventory[item_id].quantity + quantity
		_inventory.erase(item_id)
		
		# Emit signals
		item_removed.emit(item_id, old_quantity)
		inventory_updated.emit(item_id, 0)
	else:
		# Emit signals for reduced quantity
		item_removed.emit(item_id, quantity)
		inventory_updated.emit(item_id, _inventory[item_id].quantity)
	
	return true

func has_item(item_id: String, quantity: int = 1):
	"""Checks if inventory has an item"""
	return _inventory.has(item_id) and _inventory[item_id].quantity >= quantity

func get_item_quantity(item_id: String):
	"""Returns the quantity of an item"""
	if has_item(item_id):
		return _inventory[item_id].quantity
	return 0

func get_item_quality(item_id: String):
	"""Returns the quality of an item"""
	if has_item(item_id):
		return _inventory[item_id].quality
	return 0.0

func get_all_items():
	"""Returns a copy of the entire inventory"""
	return _inventory.duplicate(true)  # Deep copy

func clear_inventory():
	"""Clears the entire inventory"""
	_inventory.clear()
	inventory_updated.emit("", 0)
	return true

func get_inventory_space():
	"""Returns the amount of free inventory space"""
	return _inventory_size - _inventory.size()

func get_inventory_size():
	"""Returns the maximum inventory size"""
	return _inventory_size

func set_inventory_size(new_size):
	"""Sets a new inventory size"""
	_inventory_size = max(new_size, _inventory.size())
	return _inventory_size

# Private methods
func _is_inventory_full():
	"""Checks if inventory is full"""
	return _inventory.size() >= _inventory_size
