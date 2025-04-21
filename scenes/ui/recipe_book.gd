extends Panel
## Recipe book UI for viewing discovered recipes

# Signals
signal recipe_selected(recipe_id)
signal recipe_brew_requested(recipe_id)
signal closed

# Onready variables
@onready var _header_label = $HeaderLabel
@onready var _close_button = $CloseButton
@onready var _tab_container = $TabContainer
@onready var _detail_panel = $DetailPanel
@onready var _recipe_title = $DetailPanel/RecipeTitle
@onready var _result_icon = $DetailPanel/ResultIcon
@onready var _description = $DetailPanel/Description
@onready var _ingredients_list = $DetailPanel/IngredientsList
@onready var _brew_button = $DetailPanel/BrewButton

# Recipe item scene
var recipe_item_scene = preload("res://scenes/ui/recipe_item.tscn")

# Private variables
var _selected_recipe_id = ""
var _filter_text = ""
var _recipe_items = {}  # Map of recipe_id to recipe item nodes

# Lifecycle methods
func _ready():
	# Connect signals
	_close_button.pressed.connect(_on_close_button_pressed)
	_brew_button.pressed.connect(_on_brew_button_pressed)
	
	# Connect tab change
	_tab_container.tab_changed.connect(_on_tab_changed)
	
	# Connect search bars
	for tab_idx in range(_tab_container.get_tab_count()):
		var tab = _tab_container.get_tab_control(tab_idx)
		var search_bar = tab.get_node_or_null("SearchBar")
		if search_bar:
			search_bar.text_changed.connect(_on_search_text_changed)
	
	# Hide detail panel initially
	_detail_panel.visible = false
	
	# Connect to RecipeManager signals
	var recipe_manager = get_node_or_null("/root/RecipeManager")
	if recipe_manager:
		recipe_manager.recipe_discovered.connect(_on_recipe_discovered)
	
	# Initial refresh
	refresh_recipes()

# Public methods
func show_panel():
	"""Shows the recipe book panel and refreshes content"""
	refresh_recipes()
	visible = true

func hide_panel():
	"""Hides the recipe book panel"""
	visible = false
	closed.emit()

func refresh_recipes():
	"""Refreshes the recipe book content"""
	# Clear existing recipe items
	_clear_recipe_items()
	
	# Get recipe manager
	var recipe_manager = get_node_or_null("/root/RecipeManager")
	if not recipe_manager:
		return
	
	# Get discovered recipes
	var discovered_recipes = recipe_manager.get_discovered_recipes()
	
	# Add recipe items by category
	for recipe_id in discovered_recipes:
		var recipe = recipe_manager.get_recipe(recipe_id)
		if recipe:
			_add_recipe_item(recipe)

func select_recipe(recipe_id):
	"""Selects a recipe and shows its details"""
	if recipe_id == _selected_recipe_id:
		return
	
	_selected_recipe_id = recipe_id
	
	# Update selection visuals
	_update_recipe_selection()
	
	# Show recipe details
	_show_recipe_details(recipe_id)
	
	recipe_selected.emit(recipe_id)

# Private methods
func _clear_recipe_items():
	"""Clears all recipe items from lists"""
	for recipe_id in _recipe_items:
		var item = _recipe_items[recipe_id]
		if item and is_instance_valid(item):
			item.queue_free()
	
	_recipe_items.clear()
	
	# Clear all recipe lists
	for tab_idx in range(_tab_container.get_tab_count()):
		var tab = _tab_container.get_tab_control(tab_idx)
		var recipes_container = tab.get_node_or_null("RecipesList/VBoxContainer")
		if recipes_container:
			for child in recipes_container.get_children():
				child.queue_free()

func _add_recipe_item(recipe):
	"""Adds a recipe item to the appropriate lists"""
	# Create recipe item
	var item = recipe_item_scene.instantiate()
	item.setup(recipe.id, recipe.name, recipe.category)
	item.pressed.connect(_on_recipe_item_pressed.bind(recipe.id))
	
	# Store reference
	_recipe_items[recipe.id] = item
	
	# Add to "All Recipes" tab
	var all_recipes_container = _tab_container.get_node("All Recipes/RecipesList/VBoxContainer")
	if all_recipes_container:
		all_recipes_container.add_child(item.duplicate())
	
	# Add to category tab if it exists
	var category_tab = _tab_container.get_node_or_null(recipe.category.capitalize())
	if category_tab:
		var category_container = category_tab.get_node_or_null("RecipesList/VBoxContainer")
		if category_container:
			category_container.add_child(item.duplicate())
	
	# Filter if needed
	if not _filter_text.empty():
		_filter_recipes(_filter_text)

func _update_recipe_selection():
	"""Updates the selection visuals for all recipe items"""
	for recipe_id in _recipe_items:
		var item = _recipe_items[recipe_id]
		if item:
			item.set_selected(recipe_id == _selected_recipe_id)

func _show_recipe_details(recipe_id):
	"""Shows detailed information about the selected recipe"""
	var recipe_manager = get_node_or_null("/root/RecipeManager")
	if not recipe_manager:
		_detail_panel.visible = false
		return
	
	var recipe = recipe_manager.get_recipe(recipe_id)
	if not recipe:
		_detail_panel.visible = false
		return
	
	# Set basic info
	_recipe_title.text = recipe.name
	_description.text = recipe.description
	
	# Load result icon
	var result_id = recipe.result_id
	var potion = recipe_manager.get_potion(result_id)
	
	if potion:
		var texture_path = "res://assets/images/potions/%s/%s.png" % [recipe.category, result_id]
		if ResourceLoader.exists(texture_path):
			_result_icon.texture = load(texture_path)
		else:
			_result_icon.texture = null
	else:
		_result_icon.texture = null
	
	# Clear existing ingredients
	for child in _ingredients_list.get_children():
		child.queue_free()
	
	# Add ingredients
	var ingredient_manager = get_node_or_null("/root/IngredientManager")
	if ingredient_manager:
		for ingredient_id in recipe.ingredients:
			var ingredient = ingredient_manager.get_ingredient(ingredient_id)
			if ingredient:
				var ingredient_label = Label.new()
				ingredient_label.text = "• " + ingredient.name
				_ingredients_list.add_child(ingredient_label)
	
	# Show the panel
	_detail_panel.visible = true
	
	# Check if brewing is possible
	_check_brewing_availability(recipe)

func _check_brewing_availability(recipe):
	"""Checks if the selected recipe can be brewed with current inventory"""
	var inventory_manager = get_node_or_null("/root/InventoryManager")
	if not inventory_manager:
		_brew_button.disabled = true
		return
	
	# Check if all ingredients are available
	var can_brew = true
	for ingredient_id in recipe.ingredients:
		if not inventory_manager.has_item(ingredient_id):
			can_brew = false
			break
	
	_brew_button.disabled = !can_brew

func _filter_recipes(filter_text):
	"""Filters recipes by search text"""
	_filter_text = filter_text.to_lower()
	
	for recipe_id in _recipe_items:
		var item = _recipe_items[recipe_id]
		if item:
			var recipe_manager = get_node_or_null("/root/RecipeManager")
			if recipe_manager:
				var recipe = recipe_manager.get_recipe(recipe_id)
				if recipe:
					var should_show = _filter_text.empty() or \
									  recipe.name.to_lower().contains(_filter_text) or \
									  recipe.description.to_lower().contains(_filter_text)
					
					# Update all instances of this item
					for tab_idx in range(_tab_container.get_tab_count()):
						var tab = _tab_container.get_tab_control(tab_idx)
						var recipes_container = tab.get_node_or_null("RecipesList/VBoxContainer")
						if recipes_container:
							for child in recipes_container.get_children():
								if child.recipe_id == recipe_id:
									child.visible = should_show

func _on_close_button_pressed():
	"""Handles close button press"""
	hide_panel()

func _on_recipe_item_pressed(recipe_id):
	"""Handles recipe item selection"""
	select_recipe(recipe_id)

func _on_brew_button_pressed():
	"""Handles brew button press"""
	if _selected_recipe_id == "":
		return
	
	recipe_brew_requested.emit(_selected_recipe_id)

func _on_tab_changed(_tab_index):
	"""Handles changing between tabs"""
	# Reset filter when changing tabs
	for tab_idx in range(_tab_container.get_tab_count()):
		var tab = _tab_container.get_tab_control(tab_idx)
		var search_bar = tab.get_node_or_null("SearchBar")
		if search_bar:
			search_bar.text = _filter_text

func _on_search_text_changed(text):
	"""Handles search text changes"""
	_filter_recipes(text)

func _on_recipe_discovered(recipe_id):
	"""Called when a new recipe is discovered"""
	var recipe_manager = get_node_or_null("/root/RecipeManager")
	if recipe_manager:
		var recipe = recipe_manager.get_recipe(recipe_id)
		if recipe:
			_add_recipe_item(recipe)
