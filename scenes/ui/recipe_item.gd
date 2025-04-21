extends Button
## Represents a single recipe item in the recipe list

# Properties
@export var recipe_id: String = ""
@export var recipe_name: String = ""
@export var recipe_category: String = ""
@export var is_brewable: bool = false

# Node references
@onready var _category_indicator = $CategoryIndicator
@onready var _recipe_name_label = $HBoxContainer/RecipeName
@onready var _recipe_status = $HBoxContainer/RecipeStatus

# Lifecycle methods
func _ready():
	update_display()

# Public methods
func setup(p_recipe_id: String, p_recipe_name: String, p_category: String):
	"""Sets up the recipe item with the given data"""
	recipe_id = p_recipe_id
	recipe_name = p_recipe_name
	recipe_category = p_category
	update_display()
	return self

func set_selected(is_selected: bool):
	"""Updates the selection state"""
	if is_selected:
		add_theme_color_override("font_color", Color(0.2, 0.8, 0.4))
		add_theme_color_override("font_pressed_color", Color(0.2, 0.8, 0.4))
		if _category_indicator:
			_category_indicator.modulate = Color(1, 1, 1, 1)
	else:
		remove_theme_color_override("font_color")
		remove_theme_color_override("font_pressed_color")
		if _category_indicator:
			_category_indicator.modulate = Color(1, 1, 1, 0.5)

func set_brewable(brewable: bool):
	"""Sets whether this recipe can be brewed with current ingredients"""
	is_brewable = brewable
	if _recipe_status:
		_recipe_status.visible = is_brewable
		
		# Update tooltip
		tooltip_text = "Can be brewed with current ingredients" if is_brewable else ""

# Private methods
func update_display():
	"""Updates the visual display"""
	if _recipe_name_label:
		_recipe_name_label.text = recipe_name
	
	# Set button text as fallback
	text = recipe_name
	
	# Update category indicator color
	if _category_indicator:
		var category_color = Color.WHITE
		match recipe_category:
			"healing":
				category_color = Color(0.2, 0.8, 0.4)  # Green
			"utility":
				category_color = Color(0.4, 0.6, 0.8)  # Blue
			"transformation":
				category_color = Color(0.8, 0.4, 0.8)  # Purple
			"mind":
				category_color = Color(0.8, 0.8, 0.4)  # Yellow
		
		_category_indicator.color = category_color
		
	# Update brewable status
	if _recipe_status:
		_recipe_status.visible = is_brewable
