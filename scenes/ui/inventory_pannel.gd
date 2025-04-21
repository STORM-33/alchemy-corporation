extends Panel
## Inventory panel for managing ingredients and potions

# Signals
signal item_selected(item_id)
signal item_used(item_id)
signal item_drag_started(item_id)
signal closed

# Onready variables
@onready var _header_label = $HeaderLabel
@onready var _close_button = $CloseButton
@onready var _tab_container = $TabContainer
@onready var _ingredients_grid = $TabContainer/Ingredients/ItemGrid
@onready var _potions_grid = $TabContainer/Potions/ItemGrid
@onready var _item_info_panel = $ItemInfoPanel
@onready var _item_icon = $ItemInfoPanel/ItemIcon
@onready var _item_name = $ItemInfoPanel/ItemName
@onready var _item_description = $ItemInfoPanel/ItemDescription
@onready var _item_properties = $ItemInfoPanel/ItemProperties
@onready var _use_button = $ItemInfoPanel/ActionButtons/UseButton
@onready var _drop_button = $ItemInfoPanel/ActionButtons/DropButton

# Scene references
var INVENTORY_SLOT_SCENE = preload("res://scenes/ui/inventory_slot.tscn")

# Private variables
var _selected_item_id = ""
var _selected_item_type = ""  # "ingredient" or "potion"
var _current_filter = "all"
var _inventory_slots = {}  # Maps item_id to slot node

# Lifecycle methods
func _ready():
	# Connect signals
	_close_button.pressed.connect(_on_close_button_pressed)
	_use_button.pressed.connect(_on_use_button_pressed)
	_drop_button.pressed.connect(_on_drop_button_pressed)
	
	# Tab signals
	_tab_container.tab_changed.connect(_on_tab_changed)
	
	# Hide item info by default
	_item_info_panel.visible = false
	
	# Connect to inventory manager signals
	var inventory_manager = get_node_or_null("/root/InventoryManager")
	if inventory_manager:
		inventory_manager.inventory_updated.connect(_on_inventory_updated)
		inventory_manager.item_added.connect(_on_item_added)
		inventory_manager.item_removed.connect(_on_item_removed)
	
	# Initial refresh
	refresh_inventory()

# Public methods
func show_panel():
	"""Shows the inventory panel and refreshes content"""
	refresh_inventory()
	visible = true

func hide_panel():
	"""Hides the inventory panel"""
	visible = false
	closed.emit()

func refresh_inventory():
	"""Refreshes the entire inventory display"""
	_clear_inventory_grids()
	
	var inventory_manager = get_node_or_null("/root/InventoryManager")
	if not inventory_manager:
		return
	
	var all_items = inventory_manager.get_all_items()
	
	# Process all items
	for item_id in all_items:
		var item_data = all_items[item_id]
		var quantity = item_data.quantity
		var quality = item_data.quality
		
		_add_item_to_grid(item_id, quantity, quality)
	
	# Update slot count label
	var slots_used = all_items.size()
	var total_slots = inventory_manager._inventory_size
	_header_label.text = "Inventory (%d/%d)" % [slots_used, total_slots]

func select_item(item_id):
	"""Selects an item and shows its details"""
	if item_id == _selected_item_id:
		return
	
	_selected_item_id = item_id
	
	# Determine item type
	if item_id.begins_with("ing_"):
		_selected_item_type = "ingredient"
	elif item_id.begins_with("pot_"):
		_selected_item_type = "potion"
	else:
		_selected_item_type = ""
	
	# Update selection visuals
	_update_slot_selection()
	
	# Show item details
	_show_item_details(item_id)
	
	item_selected.emit(item_id)

func deselect_item():
	"""Deselects the current item"""
	_selected_item_id = ""
	_selected_item_type = ""
	
	_update_slot_selection()
	_item_info_panel.visible = false

# Private methods
func _clear_inventory_grids():
	"""Clears all inventory slot displays"""
	# Store existing slots for reuse
	var existing_ingredients = {}
	var existing_potions = {}
	
	for child in _ingredients_grid.get_children():
		existing_ingredients[child.item_id] = child
		child.queue_free()
	
	for child in _potions_grid.get_children():
		existing_potions[child.item_id] = child
		child.queue_free()
	
	_inventory_slots.clear()

func _add_item_to_grid(item_id, quantity, quality):
	"""Adds an item to the appropriate grid"""
	var slot = INVENTORY_SLOT_SCENE.instantiate()
	
	# Configure slot
	slot.setup(item_id, quantity, quality)
	slot.pressed.connect(_on_inventory_slot_pressed.bind(item_id))
	slot.gui_input.connect(_on_inventory_slot_input.bind(item_id))
	
	# Store reference to slot
	_inventory_slots[item_id] = slot
	
	# Add to appropriate grid
	if item_id.begins_with("ing_"):
		_ingredients_grid.add_child(slot)
	elif item_id.begins_with("pot_"):
		_potions_grid.add_child(slot)

func _update_slot_selection():
	"""Updates the selection visuals for all slots"""
	for item_id in _inventory_slots:
		var slot = _inventory_slots[item_id]
		slot.set_selected(item_id == _selected_item_id)

func _show_item_details(item_id):
	"""Shows detailed information about the selected item"""
	var item_data = _get_item_data(item_id)
	if not item_data:
		_item_info_panel.visible = false
		return
	
	# Set basic info
	_item_name.text = item_data.name
	_item_description.text = item_data.description
	
	# Load icon
	var texture_path = ""
	if item_id.begins_with("ing_"):
		texture_path = "res://assets/images/ingredients/%s/%s.png" % [item_data.category, item_id]
	else:  # Potion
		texture_path = "res://assets/images/potions/%s/%s.png" % [item_data.category, item_id]
	
	if ResourceLoader.exists(texture_path):
		_item_icon.texture = load(texture_path)
	else:
		_item_icon.texture = null
	
	# Clear existing properties
	for child in _item_properties.get_children():
		child.queue_free()
	
	# Add properties
	if item_data.has("properties"):
		for prop_name in item_data.properties:
			var prop_value = item_data.properties[prop_name]
			var prop_label = Label.new()
			prop_label.text = "%s: %.1f" % [prop_name.capitalize(), prop_value]
			_item_properties.add_child(prop_label)
	
	# Configure action buttons
	if _selected_item_type == "ingredient":
		_use_button.text = "Use in Brewing"
	else:  # Potion
		_use_button.text = "Use Potion"
	
	# Show the panel
	_item_info_panel.visible = true

func _get_item_data(item_id):
	"""Gets data for the given item ID"""
	if item_id.begins_with("ing_"):
		var ingredient_manager = get_node_or_null("/root/IngredientManager")
		if ingredient_manager:
			return ingredient_manager.get_ingredient(item_id)
	elif item_id.begins_with("pot_"):
		var recipe_manager = get_node_or_null("/root/RecipeManager")
		if recipe_manager:
			return recipe_manager.get_potion(item_id)
	
	return null

func _on_close_button_pressed():
	"""Handles close button press"""
	hide_panel()

func _on_inventory_slot_pressed(item_id):
	"""Handles inventory slot selection"""
	select_item(item_id)

func _on_inventory_slot_input(event, item_id):
	"""Handles advanced input on inventory slots"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:  # Changed from BUTTON_RIGHT
			# Right click - context menu or quick use
			if item_id.begins_with("pot_"):
				_use_item(item_id)
		
		# Drag and drop logic could be added here
	
	# Double-click detection could be added here

func _on_use_button_pressed():
	"""Handles use button press"""
	if _selected_item_id == "":
		return
	
	_use_item(_selected_item_id)

func _on_drop_button_pressed():
	"""Handles drop button press"""
	if _selected_item_id == "":
		return
	
	var inventory_manager = get_node_or_null("/root/InventoryManager")
	if inventory_manager:
		inventory_manager.remove_item(_selected_item_id, 1)
		
		# If item is completely gone, deselect
		if not inventory_manager.has_item(_selected_item_id):
			deselect_item()

func _use_item(item_id):
	"""Uses the given item"""
	item_used.emit(item_id)
	
	# For ingredients, this would be handled by the brewing system
	# For potions, apply effects immediately
	if item_id.begins_with("pot_"):
		var inventory_manager = get_node_or_null("/root/InventoryManager")
		if inventory_manager:
			inventory_manager.remove_item(item_id, 1)
			
			# If potion is completely used up, deselect
			if not inventory_manager.has_item(item_id):
				deselect_item()

func _on_tab_changed(tab_index):
	"""Handles changing between tabs"""
	# Deselect current item if switching to a tab where it doesn't belong
	if _selected_item_id != "":
		if tab_index == 0 and not _selected_item_id.begins_with("ing_"):
			deselect_item()
		elif tab_index == 1 and not _selected_item_id.begins_with("pot_"):
			deselect_item()

func _on_inventory_updated(item_id, new_quantity):
	"""Called when inventory is updated"""
	# Complete refresh if this is a general update
	if item_id == "":
		refresh_inventory()
		return
	
	# If it's the selected item and quantity is 0, deselect
	if item_id == _selected_item_id and new_quantity <= 0:
		deselect_item()

func _on_item_added(item_id, quantity):
	"""Called when an item is added to inventory"""
	# Refresh the whole inventory for simplicity
	# Could be optimized to just update the affected slot
	refresh_inventory()

func _on_item_removed(item_id, quantity):
	"""Called when an item is removed from inventory"""
	# Refresh the whole inventory for simplicity
	# Could be optimized to just update the affected slot
	refresh_inventory()
