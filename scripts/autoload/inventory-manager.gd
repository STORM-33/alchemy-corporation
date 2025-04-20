extends Node
## Manages the player's inventory of ingredients and potions
## Add this script to an autoload in the Project Settings

# Signals
signal inventory_updated(item_id, new_quantity)
signal item_added(item_id, quantity)
signal item_removed(item_id, quantity)
signal inventory_full()

# Constants
const MAX_INVENTORY_SIZE = 20  # Initial inventory size
const INVENTORY_UPGRADE_INCREMENT = 5  # Size increase per upgrade

# Private variables
var _inventory = {}  # Dictionary of item_id: {quantity, quality}
var _inventory_size = MAX_INVENTORY_SIZE
var _inventory_upgrades = 0

# Lifecycle methods
func _ready():
    # Register with GameManager
    if GameManager:
        GameManager.inventory_manager = self

# Public methods
func add_item(item_id, quantity=1, quality=1.0):
    """
    Adds an item to the inventory
    Returns: Amount actually added (may be less if inventory full)
    """
    if not _inventory.has(item_id):
        # Check if we can add this new item
        if _inventory.size() >= _inventory_size:
            emit_signal("inventory_full")
            return 0
        
        # New item
        _inventory[item_id] = {
            "quantity": quantity,
            "quality": quality
        }
        
        emit_signal("item_added", item_id, quantity)
        emit_signal("inventory_updated", item_id, quantity)
        return quantity
    else:
        # Existing item, update quantity and average quality
        var current = _inventory[item_id]
        var new_quantity = current.quantity + quantity
        
        # Calculate new average quality
        var new_quality = (current.quality * current.quantity + quality * quantity) / new_quantity
        
        _inventory[item_id] = {
            "quantity": new_quantity,
            "quality": new_quality
        }
        
        emit_signal("item_added", item_id, quantity)
        emit_signal("inventory_updated", item_id, new_quantity)
        return quantity

func remove_item(item_id, quantity=1):
    """
    Removes an item from the inventory
    Returns: Amount actually removed
    """
    if not _inventory.has(item_id):
        return 0
        
    var current = _inventory[item_id]
    
    # Determine amount we can actually remove
    var amount_to_remove = min(quantity, current.quantity)
    
    if amount_to_remove <= 0:
        return 0
        
    # Update quantity
    current.quantity -= amount_to_remove
    
    # Remove item entirely if quantity is zero
    if current.quantity <= 0:
        _inventory.erase(item_id)
    else:
        _inventory[item_id] = current
    
    emit_signal("item_removed", item_id, amount_to_remove)
    emit_signal("inventory_updated", item_id, current.quantity if current.quantity > 0 else 0)
    
    return amount_to_remove

func has_item(item_id, quantity=1):
    """Checks if the inventory has at least the given quantity of an item"""
    if not _inventory.has(item_id):
        return false
        
    return _inventory[item_id].quantity >= quantity

func get_item_quantity(item_id):
    """Returns the quantity of the specified item, or 0 if not present"""
    if not _inventory.has(item_id):
        return 0
        
    return _inventory[item_id].quantity

func get_item_quality(item_id):
    """Returns the quality of the specified item, or 0 if not present"""
    if not _inventory.has(item_id):
        return 0
        
    return _inventory[item_id].quality

func get_all_items():
    """Returns a dictionary with all inventory contents"""
    return _inventory.duplicate(true)

func get_items_by_category(category):
    """Returns all items in a specific category"""
    var result = {}
    
    for item_id in _inventory.keys():
        var item_data = _get_item_data(item_id)
        if item_data and item_data.category == category:
            result[item_id] = _inventory[item_id]
    
    return result

func is_inventory_full():
    """Returns true if the inventory is at maximum capacity"""
    return _inventory.size() >= _inventory_size

func upgrade_inventory():
    """
    Increases the inventory size by one upgrade increment
    Returns true if upgrade successful
    """
    _inventory_upgrades += 1
    _inventory_size = MAX_INVENTORY_SIZE + (_inventory_upgrades * INVENTORY_UPGRADE_INCREMENT)
    return true

func get_remaining_slots():
    """Returns number of empty inventory slots"""
    return _inventory_size - _inventory.size()

func clear_inventory():
    """Removes all items from inventory (use with caution!)"""
    _inventory.clear()
    emit_signal("inventory_updated", "", 0)

func get_save_data():
    """Returns a dictionary with all data needed to save inventory state"""
    return {
        "inventory": _inventory,
        "inventory_size": _inventory_size,
        "inventory_upgrades": _inventory_upgrades
    }

func load_save_data(data):
    """Loads inventory state from saved data"""
    if data.has("inventory"):
        _inventory = data.inventory.duplicate(true)
    
    if data.has("inventory_size"):
        _inventory_size = data.inventory_size
    
    if data.has("inventory_upgrades"):
        _inventory_upgrades = data.inventory_upgrades
    
    emit_signal("inventory_updated", "", 0)

# Private methods
func _get_item_data(item_id):
    """
    Retrieves the item definition from the appropriate manager
    Returns null if not found
    """
    # Check if this is an ingredient
    if item_id.begins_with("ing_"):
        if has_node("/root/IngredientManager"):
            return get_node("/root/IngredientManager").get_ingredient(item_id)
    
    # Check if this is a potion
    elif item_id.begins_with("pot_"):
        if has_node("/root/RecipeManager"):
            return get_node("/root/RecipeManager").get_potion(item_id)
    
    return null
