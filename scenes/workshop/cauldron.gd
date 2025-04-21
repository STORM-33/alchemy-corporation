extends Node2D
## Cauldron brewing station for creating potions

# Signals
signal brewing_started(recipe_id)
signal brewing_progress(progress)
signal brewing_completed(potion_id, potion_name, quality)
signal ingredient_added(slot_index, ingredient_id)
signal ingredient_removed(slot_index, ingredient_id)

# Constants
const MAX_INGREDIENTS = 4
const BASE_BREWING_TIME = 10.0  # Seconds

# Exported variables
@export var idle_liquid_color: Color = Color(0.5, 0.5, 0.5, 0.8)
@export var brewing_liquid_color: Color = Color(0.2, 0.8, 0.4, 0.9)
@export var error_liquid_color: Color = Color(0.8, 0.2, 0.2, 0.9)
@export var can_fail: bool = true

# Onready variables
@onready var _liquid_display = $LiquidDisplay
@onready var _brewing_particles = $BrewingParticles
@onready var _brewing_timer = $BrewingTimer
@onready var _ingredient_slots = $IngredientSlots
@onready var _brew_button = $BrewButton
@onready var _progress_bar = $ProgressBar

# Private variables
var _current_ingredients = []  # List of ingredient IDs
var _current_recipe_id = ""
var _is_brewing = false
var _brewing_progress = 0.0
var _station_level = 1

# Lifecycle methods
func _ready():
	# Initialize appearance
	_update_liquid_display(idle_liquid_color)
	if _brewing_particles:
		_brewing_particles.emitting = false
	
	# Connect timer signal
	if _brewing_timer:
		_brewing_timer.timeout.connect(_on_brewing_completed)
	
	# Connect brew button
	if _brew_button:
		_brew_button.pressed.connect(_on_brew_button_pressed)
	
	# Connect ingredient slot signals
	for i in range(1, MAX_INGREDIENTS + 1):
		var slot = _ingredient_slots.get_node_or_null("Slot" + str(i))
		if slot:
			slot.gui_input.connect(_on_slot_input.bind(i-1))
	
	# Hide progress bar initially
	if _progress_bar:
		_progress_bar.visible = false
	
	# Get station level from GameManager
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.station_levels.has("cauldron"):
		_station_level = game_manager.station_levels["cauldron"]

	# Set process off until needed
	set_process(false)

# Process for updating brewing progress visuals
func _process(delta):
	if _is_brewing and _brewing_timer and _brewing_timer.time_left > 0:
		_brewing_progress = 1.0 - (_brewing_timer.time_left / _brewing_timer.wait_time)
		if _progress_bar:
			_progress_bar.value = _brewing_progress
		brewing_progress.emit(_brewing_progress)

# Public methods
func add_ingredient(ingredient_id, slot_index = -1):
	"""
	Adds an ingredient to the cauldron
	If slot_index is -1, adds to the first available slot
	Returns success status
	"""
	if _is_brewing:
		return false
	
	# Check if we can add more ingredients
	if _current_ingredients.size() >= MAX_INGREDIENTS:
		return false
	
	# If no specific slot requested, find first available
	if slot_index == -1:
		slot_index = _current_ingredients.size()
	
	# Make sure slot is valid
	if slot_index < 0 or slot_index >= MAX_INGREDIENTS:
		return false
	
	# Add ingredient
	if slot_index >= _current_ingredients.size():
		# Add to end
		_current_ingredients.append(ingredient_id)
	else:
		# Replace existing
		_current_ingredients[slot_index] = ingredient_id
	
	# Update slot visual
	_update_ingredient_slot(slot_index)
	
	ingredient_added.emit(slot_index, ingredient_id)
	return true

func remove_ingredient(slot_index):
	"""Removes an ingredient from the specified slot"""
	if _is_brewing:
		return false
	
	if slot_index < 0 or slot_index >= _current_ingredients.size():
		return false
	
	var ingredient_id = _current_ingredients[slot_index]
	_current_ingredients.remove_at(slot_index)  # Changed to remove_at in Godot 4
	
	# Update slot visuals
	_update_all_slots()
	
	ingredient_removed.emit(slot_index, ingredient_id)
	return true

func clear_ingredients():
	"""Removes all ingredients from the cauldron"""
	if _is_brewing:
		return false
	
	var old_ingredients = _current_ingredients.duplicate()
	_current_ingredients.clear()
	
	_update_all_slots()
	
	for i in range(old_ingredients.size()):
		ingredient_removed.emit(i, old_ingredients[i])
	
	return true

func get_ingredients():
	"""Returns the current ingredients list"""
	return _current_ingredients.duplicate()

func brew_potion(recipe_id = "", custom_ingredients = null):
	"""
	Starts brewing a potion
	If recipe_id is specified, uses that recipe
	If custom_ingredients is provided, uses those instead of current ingredients
	Returns a dictionary with success status and details
	"""
	if _is_brewing:
		return {"success": false, "error": "Already brewing"}
	
	# Use provided ingredients or current ones
	var ingredients_to_use = custom_ingredients if custom_ingredients != null else _current_ingredients
	
	# Check if we have ingredients
	if ingredients_to_use.empty():
		return {"success": false, "error": "No ingredients"}
	
	# If no recipe specified, try to find a matching one
	var recipe_name = "Unknown Concoction"
	var found_recipe = false
	
	if recipe_id == "":
		var recipe_result = _find_matching_recipe(ingredients_to_use)
		if recipe_result.found:
			recipe_id = recipe_result.recipe_id
			recipe_name = recipe_result.recipe_name
			found_recipe = true
	else:
		# Use provided recipe
		var recipe_manager = get_node_or_null("/root/RecipeManager")
		if recipe_manager:
			var recipe_data = recipe_manager.get_recipe(recipe_id)
			if recipe_data:
				recipe_name = recipe_data.name
				found_recipe = true
	
	# Start brewing
	_current_recipe_id = recipe_id
	_is_brewing = true
	
	# Calculate brewing time based on ingredients and station level
	var brewing_time = _calculate_brewing_time(ingredients_to_use, found_recipe)
	
	# Update visuals
	_update_liquid_display(brewing_liquid_color)
	if _brewing_particles:
		_brewing_particles.emitting = true
	
	# Show and update progress bar
	if _progress_bar:
		_progress_bar.visible = true
		_progress_bar.value = 0
	
	# Start timer
	if _brewing_timer:
		_brewing_timer.wait_time = brewing_time
		_brewing_timer.start()
	
	# Start processing for progress updates
	set_process(true)
	
	# Signal that brewing started
	brewing_started.emit(recipe_id)
	
	return {
		"success": true, 
		"recipe_id": recipe_id,
		"recipe_name": recipe_name,
		"brewing_time": brewing_time,
		"recipe_found": found_recipe
	}

func stop_brewing():
	"""Cancels the current brewing process"""
	if not _is_brewing:
		return false
	
	if _brewing_timer:
		_brewing_timer.stop()
	
	_is_brewing = false
	
	# Reset visuals
	_update_liquid_display(idle_liquid_color)
	if _brewing_particles:
		_brewing_particles.emitting = false
	
	if _progress_bar:
		_progress_bar.visible = false
	
	set_process(false)
	
	return true

# Private methods
func _update_liquid_display(color):
	"""Updates the liquid display with the given color"""
	if _liquid_display:
		_liquid_display.modulate = color

func _update_ingredient_slot(slot_index):
	"""Updates the visual for a specific ingredient slot"""
	if slot_index < 0 or slot_index >= MAX_INGREDIENTS:
		return
	
	var slot_node = _ingredient_slots.get_node_or_null("Slot" + str(slot_index + 1))
	if not slot_node:
		return
	
	if slot_index < _current_ingredients.size():
		# Slot has an ingredient
		var ingredient_id = _current_ingredients[slot_index]
		var ingredient_texture = _get_ingredient_texture(ingredient_id)
		
		if ingredient_texture:
			slot_node.texture = ingredient_texture
			slot_node.modulate = Color(1, 1, 1, 1)
		else:
			# No texture found, show placeholder
			slot_node.modulate = Color(0.5, 0.5, 0.5, 1)
	else:
		# Empty slot
		slot_node.texture = null
		slot_node.modulate = Color(0.3, 0.3, 0.3, 0.5)

func _update_all_slots():
	"""Updates all ingredient slot visuals"""
	for i in range(MAX_INGREDIENTS):
		_update_ingredient_slot(i)

func _get_ingredient_texture(ingredient_id):
	"""Gets the texture for an ingredient"""
	# Try to load from the ingredient manager
	var ingredient_manager = get_node_or_null("/root/IngredientManager")
	if ingredient_manager:
		var ingredient = ingredient_manager.get_ingredient(ingredient_id)
		if ingredient:
			var texture_path = ingredient.get_icon_path()
			if ResourceLoader.exists(texture_path):
				return load(texture_path)
			else:
				# Return a placeholder if the specific texture doesn't exist
				return load("res://assets/images/ui/icons/unknown_item.png")
	
	# Default fallback
	return load("res://assets/images/ui/icons/unknown_item.png")

func _find_matching_recipe(ingredients):
	"""Tries to find a recipe matching the current ingredients"""
	var recipe_manager = get_node_or_null("/root/RecipeManager")
	if not recipe_manager:
		return {"found": false}
	
	var result = recipe_manager.find_recipe_by_ingredients(ingredients)
	return result

func _calculate_brewing_time(ingredients, has_recipe):
	"""Calculates brewing time based on ingredients and station level"""
	var base_time = BASE_BREWING_TIME
	
	# More ingredients = more time
	var ingredient_factor = 1.0 + (ingredients.size() * 0.2)  # +20% per ingredient
	
	# Known recipes are faster
	var recipe_factor = 0.8 if has_recipe else 1.2  # 20% faster for known recipes
	
	# Higher station level reduces time
	var level_factor = 1.0 - ((_station_level - 1) * 0.1)  # -10% per level
	level_factor = max(0.5, level_factor)  # Cap at 50% reduction
	
	var total_time = base_time * ingredient_factor * recipe_factor * level_factor
	
	return total_time

func _on_brewing_completed():
	"""Called when brewing timer completes"""
	_is_brewing = false
	set_process(false)
	
	# Get brewing result
	var result = _calculate_brewing_result()
	
	# Reset visuals
	_update_liquid_display(idle_liquid_color)
	if _brewing_particles:
		_brewing_particles.emitting = false
	
	if _progress_bar:
		_progress_bar.visible = false
	
	# Generate potion
	var inventory_manager = get_node_or_null("/root/InventoryManager")
	if inventory_manager and result.success:
		inventory_manager.add_item(result.potion_id, 1, result.quality)
		
		# Notify the player
		var notification_system = get_node_or_null("/root/NotificationSystem")
		if notification_system:
			notification_system.show_success("Created " + result.potion_name)
	
	# Clear ingredients if successful
	if result.success:
		clear_ingredients()
	
	# Signal completion
	brewing_completed.emit(result.potion_id, result.potion_name, result.quality)

func _calculate_brewing_result():
	"""Calculates the result of the brewing process"""
	var recipe_manager = get_node_or_null("/root/RecipeManager")
	
	# Default for experimental brewing
	var result = {
		"success": true,
		"potion_id": "pot_unknown_mixture",
		"potion_name": "Unknown Mixture",
		"quality": 1.0
	}
	
	# If we have a recipe, use that
	if _current_recipe_id != "" and recipe_manager:
		var recipe = recipe_manager.get_recipe(_current_recipe_id)
		if recipe:
			result.potion_id = recipe.result_id
			result.potion_name = recipe.name
			
			# Calculate quality based on station level and player skill
			var game_manager = get_node_or_null("/root/GameManager")
			var specialization_bonus = 0
			
			if game_manager:
				if recipe.category == "healing":
					specialization_bonus = game_manager.specializations.healing
				elif recipe.category == "utility":
					specialization_bonus = game_manager.specializations.utility
				elif recipe.category == "transformation":
					specialization_bonus = game_manager.specializations.transformation
				elif recipe.category == "mind":
					specialization_bonus = game_manager.specializations.mind
			
			# Base quality with some randomness
			var base_quality = 1.0
			var random_factor = randf_range(-0.1, 0.1)  # Changed from rand_range to randf_range
			
			# Station level bonus
			var level_bonus = (_station_level - 1) * 0.1  # +10% per level
			
			# Specialization bonus
			var spec_bonus = specialization_bonus * 0.05  # +5% per specialization level
			
			result.quality = base_quality + random_factor + level_bonus + spec_bonus
			result.quality = clamp(result.quality, 0.5, 2.0)  # Between 50% and 200%
			
			# Discover the recipe if it was found by experiment
			if not recipe.discovered:
				recipe_manager.discover_recipe(recipe.id)
	else:
		# Experimental brewing - to be expanded with property system
		result.success = !can_fail || (randf() > 0.3)  # 30% chance of failure if can_fail is true
		
		if !result.success:
			result.potion_id = "pot_failed_experiment"
			result.potion_name = "Failed Experiment"
			result.quality = 0.5
	
	return result

func _on_slot_input(event, slot_index):
	"""Handles input on ingredient slots"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:  # Changed from BUTTON_LEFT
			# Left click - interact with slot
			if slot_index < _current_ingredients.size():
				# Remove ingredient if it exists
				remove_ingredient(slot_index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:  # Changed from BUTTON_RIGHT
			# Right click - show info about ingredient
			if slot_index < _current_ingredients.size():
				var ingredient_id = _current_ingredients[slot_index]
				
				# Show ingredient info via notification system
				var ingredient_manager = get_node_or_null("/root/IngredientManager")
				var notification_system = get_node_or_null("/root/NotificationSystem")
				
				if ingredient_manager and notification_system:
					var ingredient = ingredient_manager.get_ingredient(ingredient_id)
					if ingredient:
						notification_system.show_info(ingredient.name + ": " + ingredient.description)

func _on_brew_button_pressed():
	"""Handles brew button press"""
	if _is_brewing:
		return
	
	if _current_ingredients.empty():
		# Notify the player they need ingredients
		var notification_system = get_node_or_null("/root/NotificationSystem")
		if notification_system:
			notification_system.show_warning("Add ingredients first!")
		return
	
	# Start brewing
	brew_potion()
