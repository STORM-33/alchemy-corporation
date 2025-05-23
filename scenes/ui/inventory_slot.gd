extends TextureRect
## Represents a single inventory slot with drag-and-drop support
## This is an updated version of your existing inventory_slot.gd

# Signals
signal quantity_changed(new_quantity)
signal item_drag_started(item_id)
signal item_drag_ended(success)
signal slot_clicked(item_id)
signal slot_right_clicked(item_id)

# Exported variables
@export var item_id: String = ""
@export var quantity: int = 0
@export var quality: float = 1.0

# Onready variables
@onready var _quantity_label = $QuantityLabel
@onready var _quality_indicator = $QualityIndicator
@onready var _selection_highlight = $SelectionHighlight

# Lifecycle methods
func _ready():
	# Initialize visuals
	_update_display()
	
	# Hide selection by default
	if _selection_highlight:
		_selection_highlight.visible = false

# Public methods
func setup(p_item_id, p_quantity=1, p_quality=1.0):
	"""Initializes the slot with item data"""
	item_id = p_item_id
	quantity = p_quantity
	quality = p_quality
	
	# Load item texture
	texture = _get_item_texture(item_id)
	
	_update_display()
	return self

func set_quantity(new_quantity):
	"""Updates the item quantity"""
	if new_quantity == quantity:
		return
	
	var old_quantity = quantity
	quantity = new_quantity
	
	_update_display()
	quantity_changed.emit(quantity)

func set_quality(new_quality):
	"""Updates the item quality"""
	quality = new_quality
	_update_display()

func set_selected(is_selected):
	"""Updates the selection state"""
	if _selection_highlight:
		_selection_highlight.visible = is_selected

func get_drag_data(_position):
	"""Returns drag data for drag and drop operations"""
	if item_id.is_empty() or quantity <= 0:
		return null
	
	# Create drag preview
	var preview = TextureRect.new()
	preview.texture = texture
	preview.custom_minimum_size = Vector2(50, 50)
	preview.expand_mode = 1
	
	# Set drag preview
	set_drag_preview(preview)
	
	# Signal that dragging started
	item_drag_started.emit(item_id)
	
	# Return data
	return {
		"type": "inventory_item",
		"item_id": item_id,
		"source": self
	}

func can_drop_data(_position, data):
	"""Determines if this slot can accept the dropped data"""
	# For now, we don't allow dropping on inventory slots
	# Could be implemented later for item swapping or merging
	return false

func drop_data(_position, data):
	"""Handles dropping data on this slot"""
	# Not implemented yet
	pass

# GUI input for direct clicking
func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Left click
			if not item_id.is_empty():
				slot_clicked.emit(item_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Right click
			if not item_id.is_empty():
				slot_right_clicked.emit(item_id)

# Private methods
func _update_display():
	"""Updates the visual display of the slot"""
	# Update quantity label
	if _quantity_label:
		if quantity <= 1:
			_quantity_label.visible = false
		else:
			_quantity_label.visible = true
			_quantity_label.text = str(quantity)
	
	# Update quality indicator
	if _quality_indicator:
		# Only show quality for non-basic items
		if quality > 0.9 and quality < 1.1:
			_quality_indicator.visible = false
		else:
			_quality_indicator.visible = true
			
			# Quality ranges from 0.5 to 2.0
			var quality_percent = (quality - 0.5) / 1.5 * 100
			_quality_indicator.value = quality_percent
			
			# Color based on quality
			if quality >= 1.5:
				_quality_indicator.tint_progress = Color(0.3, 0.9, 0.3)  # Green for high quality
			elif quality >= 1.0:
				_quality_indicator.tint_progress = Color(0.9, 0.9, 0.3)  # Yellow for normal quality
			else:
				_quality_indicator.tint_progress = Color(0.9, 0.3, 0.3)  # Red for low quality

func _get_item_texture(p_item_id):
	"""Loads the texture for the given item ID"""
	if p_item_id.empty():
		return null
	
	var texture_path = ""
	
	# Determine path based on item type
	if p_item_id.begins_with("ing_"):
		# Get category from IngredientManager
		var ingredient_manager = get_node_or_null("/root/IngredientManager")
		if ingredient_manager:
			var ingredient = ingredient_manager.get_ingredient(p_item_id)
			if ingredient:
				texture_path = ingredient.get_icon_path()
	elif p_item_id.begins_with("pot_"):
		# For potions we need a different path
		var recipe_manager = get_node_or_null("/root/RecipeManager")
		if recipe_manager:
			var potion = recipe_manager.get_potion(p_item_id)
			if potion:
				texture_path = "res://assets/images/potions/%s/%s.png" % [potion.category, p_item_id]
	
	# Try to load the texture
	if texture_path and ResourceLoader.exists(texture_path):
		return load(texture_path)
	
	# Return default/placeholder texture if not found
	return load("res://assets/images/ui/icons/unknown_item.png")
