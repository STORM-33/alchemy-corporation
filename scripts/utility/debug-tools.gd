extends Node
## Testing tools for development
## Attach to a node in the scene for quick debugging

# Onready variables
onready var _debug_ui = $DebugUI
onready var _add_gold_button = $DebugUI/Panel/VBoxContainer/AddGoldButton
onready var _add_ingredients_button = $DebugUI/Panel/VBoxContainer/AddIngredientsButton
onready var _debug_panel = $DebugUI/Panel

# Lifecycle methods
func _ready():
    # Connect debug buttons
    _add_gold_button.connect("pressed", self, "_on_add_gold_pressed")
    _add_ingredients_button.connect("pressed", self, "_on_add_ingredients_pressed")
    
    # Connect keyboard shortcuts
    # Toggle debug panel with F1
    
    # Debug logging
    print("Debug tools initialized")

# Input handling
func _input(event):
    # Toggle debug panel with F1
    if event is InputEventKey and event.pressed and event.scancode == KEY_F1:
        _debug_panel.visible = !_debug_panel.visible

# Debug functions
func _on_add_gold_pressed():
    """Adds 100 gold for testing"""
    var game_manager = get_node_or_null("/root/GameManager")
    if game_manager:
        game_manager.add_gold(100)
        print("Added 100 gold. New total: ", game_manager.player_gold)

func _on_add_ingredients_pressed():
    """Adds sample ingredients for testing"""
    var inventory_manager = get_node_or_null("/root/InventoryManager")
    if inventory_manager:
        # Add some common ingredients
        inventory_manager.add_item("ing_lavender", 5, 1.0)
        inventory_manager.add_item("ing_mint", 5, 1.0)
        inventory_manager.add_item("ing_quartz_dust", 3, 1.0)
        inventory_manager.add_item("ing_clay", 3, 1.0)
        print("Added test ingredients to inventory")

func get_system_status():
    """Prints the status of all game systems"""
    print("=== SYSTEM STATUS ===")
    
    # Game Manager
    var game_manager = get_node_or_null("/root/GameManager")
    if game_manager:
        print("GameManager:")
        print("  Player Level: ", game_manager.player_level)
        print("  Gold: ", game_manager.player_gold)
        print("  Essence: ", game_manager.player_essence)
        print("  Game Day: ", game_manager.current_game_day)
    else:
        print("GameManager: NOT FOUND")
    
    # Inventory
    var inventory_manager = get_node_or_null("/root/InventoryManager")
    if inventory_manager:
        print("InventoryManager:")
        print("  Items: ", inventory_manager.get_all_items().size())
        print("  Capacity: ", inventory_manager._inventory_size)
    else:
        print("InventoryManager: NOT FOUND")
    
    # Ingredients
    var ingredient_manager = get_node_or_null("/root/IngredientManager")
    if ingredient_manager:
        print("IngredientManager:")
        print("  Total Ingredients: ", ingredient_manager.get_all_ingredient_ids().size())
    else:
        print("IngredientManager: NOT FOUND")
    
    # Gathering System
    var gathering_system = get_node_or_null("/root/GatheringSystem")
    if gathering_system:
        print("GatheringSystem:")
        print("  Active Nodes: ", gathering_system.get_active_node_ids().size())
        print("  Regenerating: ", gathering_system.get_regenerating_resources().size())
    else:
        print("GatheringSystem: NOT FOUND")
    
    print("=====================")
