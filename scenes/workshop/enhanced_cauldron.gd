extends Node2D
## Enhanced cauldron brewing station with stirring mechanics and visual feedback
## Extends the basic cauldron with more interactive brewing

# Signals - extending the base cauldron signals
signal brewing_started(recipe_id)
signal brewing_progress(progress)
signal brewing_completed(potion_id, potion_name, quality)
signal ingredient_added(slot_index, ingredient_id)
signal ingredient_removed(slot_index, ingredient_id)
signal stirring_performed(count, total_needed)

# Constants
const MAX_INGREDIENTS = 4
const BASE_BREWING_TIME = 10.0  # Seconds
const MAX_STIR_COUNT = 5
const STIR_COOLDOWN = 0.5  # Time between stirs

# Exported variables
@export var liquid_colors: Dictionary = {
	"neutral": Color(0.5, 0.5, 0.5, 0.8),
	"healing": Color(0.3, 0.8, 0.4, 0.9),
	"utility": Color(0.8, 0.8, 0.3, 0.9),
	"transformation": Color(0.8, 0.4, 0.8, 0.9),
	"mind": Color(0.4, 0.6, 0.9, 0.9)
}
@export var error_liquid_color: Color = Color(0.8, 0.2, 0.2, 0.9)
@export var can_fail: bool = true
@export var max_bubbles: int = 10
@export var stir_power_multiplier: float = 1.2

# Node references
@onready var _liquid_display = $LiquidDisplay
@onready var _bubble_particles = $BubbleParticles
@onready var _steam_particles = $SteamParticles
@onready var _splash_particles = $SplashParticles
@onready var _brewing_timer = $BrewingTimer
@onready var _stir_timer = $StirTimer
@onready var _audio_player = $AudioPlayer
@onready var _ingredient_slots = $IngredientSlots
@onready var _stir_button = $StirButton
@onready var _brew_button = $BrewButton
@onready var _progress_bar = $ProgressBar
@onready var _stir_counter = $StirCounter
@onready var _property_display = $PropertyDisplay
@onready var _recipe_panel = $RecipePanel

# Private variables
var _current_ingredients = []  # List of ingredient IDs
var _current_recipe_id = ""
var _is_brewing = false
var _is_stirred = false
var _brewing_progress = 0.0
var _station_level = 1
var _stir_count = 0
var _current_properties = {}  # Properties of the current mixture
var _brewing_quality_bonus = 0.0
var _is_experimental = false

# Lifecycle methods
func _ready():
	# Initialize appearance
	_update_liquid_display(liquid_colors.neutral)
	
	# Initialize particles
	if _bubble_particles:
		_bubble_particles.emitting = false
	if _steam_particles:
		_steam_particles.emitting = false
	if _splash_particles:
		_splash_particles.emitting = false
	
	# Connect timers
	if _brewing_timer:
		_brewing_timer.timeout.connect(_on_brewing_completed)
	if _stir_timer:
		_stir_timer.timeout.connect(_on_stir_cooldown_complete)
	
	# Connect buttons
	if _brew_button:
		_brew_button.pressed.connect(_on_brew_button_pressed)
	if _stir_button:
		_stir_button.pressed.connect(_on_stir_button_pressed)
	
	# Connect ingredient slot signals
	for i in range(1, MAX_INGREDIENTS + 1):
		var slot = _ingredient_slots.get_node_or_null("Slot" + str(i))
		if slot:
			slot.gui_input.connect(_on_slot_input.bind(i-1))
	
	# Hide progress bar and stir counter initially
	if _progress_bar:
		_progress_bar.visible = false
	if _stir_counter:
		_stir_counter.visible = false
	if _recipe_panel:
		_recipe_panel.visible = false
	
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
	
	# Update properties display
	_update_properties_display()
	
	# Play sound effect
	_play_sound_effect("add_ingredient")
	
	# Make a small splash
	if _splash_particles:
		_splash_particles.emitting = true
	
	# Try to find a matching recipe
	var recipe_result = _find_matching_recipe(_current_ingredients)
	if recipe_result.found:
		_show_recipe_info(recipe_result.recipe_id)
	else:
		_hide_recipe_info()
	
	ingredient_added.emit(slot_index, ingredient_id)
	return true

func remove_ingredient(slot_index):
	"""Removes an ingredient from the specified slot"""
	if _is_brewing:
		return false
	
	if slot_index < 0 or slot_index >= _current_ingredients.size():
		return false
	
	var ingredient_id = _current_ingredients[slot_index]
	_current_ingredients.remove_at(slot_index)
	
	# Update slot visuals
	_update_all_slots()
	
	# Update properties display
	_update_properties_display()
	
	# Play sound effect
	_play_sound_effect("remove_ingredient")
	
	# Hide recipe info
	_hide_recipe_info()
	
	ingredient_removed.emit(slot_index, ingredient_id)
	return true

func clear_ingredients():
	"""Removes all ingredients from the cauldron"""
	if _is_brewing:
		return false
	
	var old_ingredients = _current_ingredients.duplicate()
	_current_ingredients.clear()
	
	_update_all_slots()
	_update_properties_display()
	_hide_recipe_info()
	
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
	
	# Reset stir count
	_stir_count = 0
	_brewing_quality_bonus = 0.0
	
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
			_is_experimental = false
		else:
			# This is an experimental brew
			_is_experimental = true
	else:
		# Use provided recipe
		var recipe_manager = get_node_or_null("/root/RecipeManager")
		if recipe_manager:
			var recipe_data = recipe_manager.get_recipe(recipe_id)
			if recipe_data:
				recipe_name = recipe_data.name
				found_recipe = true
				_is_experimental = false
	
	# Start brewing
	_current_recipe_id = recipe_id
	_is_brewing = true
	
	# Calculate brewing time based on ingredients and station level
	var brewing_time = _calculate_brewing_time(ingredients_to_use, found_recipe)
	
	# Update visuals based on recipe or experimental
	if found_recipe:
		var recipe_manager = get_node_or_null("/root/RecipeManager")
		if recipe_manager:
			var recipe = recipe_manager.get_recipe(recipe_id)
			if recipe and liquid_colors.has(recipe.category):
				_update_liquid_display(liquid_colors[recipe.category])
			else:
				_update_liquid_display(liquid_colors.neutral)
	else:
		# Experimental brewing - color based on dominant property
		var category = _determine_dominant_category()
		if liquid_colors.has(category):
			_update_liquid_display(liquid_colors[category])
		else:
			_update_liquid_display(liquid_colors.neutral)
	
	# Start particle effects
	if _bubble_particles:
		_bubble_particles.emitting = true
		# Adjust bubble count based on how many ingredients
		_bubble_particles.amount = max(5, min(max_bubbles, ingredients_to_use.size() * 3))
	
	if _steam_particles:
		_steam_particles.emitting = true
	
	# Show and update progress bar
	if _progress_bar:
		_progress_bar.visible = true
		_progress_bar.value = 0
	
	# Show stir counter if using enhanced mechanics
	if _stir_counter:
		_stir_counter.visible = true
		_stir_counter.text = "Stirs: 0/" + str(MAX_STIR_COUNT)
	
	# Start timer
	if _brewing_timer:
		_brewing_timer.wait_time = brewing_time
		_brewing_timer.start()
	
	# Start processing for progress updates
	set_process(true)
	
	# Play brewing sound
	_play_sound_effect("start_brewing")
	
	# Signal that brewing started
	brewing_started.emit(recipe_id)
	
	return {
		"success": true, 
		"recipe_id": recipe_id,
		"recipe_name": recipe_name,
		"brewing_time": brewing_time,
		"recipe_found": found_recipe
	}

func stir_cauldron():
	"""Stirs the cauldron to improve brewing quality"""
	if not _is_brewing or _stir_timer.time_left > 0:
		return false
	
	_stir_count = min(_stir_count + 1, MAX_STIR_COUNT)
	
	# Add quality bonus
	_brewing_quality_bonus += 0.1 * stir_power_multiplier
	
	# Update stir counter
	if _stir_counter:
		_stir_counter.text = "Stirs: " + str(_stir_count) + "/" + str(MAX_STIR_COUNT)
	
	# Trigger splash effect
	if _splash_particles:
		_splash_particles.emitting = true
	
	# Play stir sound
	_play_sound_effect("stir")
	
	# Start cooldown timer
	_stir_timer.start(STIR_COOLDOWN)
	
	# Signal stir performed
	stirring_performed.emit(_stir_count, MAX_STIR_COUNT)
	
	return true

func stop_brewing():
	"""Cancels the current brewing process"""
	if not _is_brewing:
		return false
	
	if _brewing_timer:
		_brewing_timer.stop()
	
	_is_brewing = false
	_is_stirred = false
	_stir_count = 0
	_brewing_quality_bonus = 0.0
	
	# Reset visuals
	_update_liquid_display(liquid_colors.neutral)
	if _bubble_particles:
		_bubble_particles.emitting = false
	if _steam_particles:
		_steam_particles.emitting = false
	
	if _progress_bar:
		_progress_bar.visible = false
	if _stir_counter:
		_stir_counter.visible = false
	
	set_process(false)
	
	# Play cancel sound
	_play_sound_effect("cancel_brewing")
	
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

func _update_properties_display():
	"""Updates the properties display based on current ingredients"""
	# Clear existing properties
	if _property_display:
		for child in _property_display.get_children():
			if child.name != "PropertyLabel":  # Keep the label
				child.queue_free()
	else:
		return
	
	# Calculate current properties
	_current_properties = _calculate_properties(_current_ingredients)
	
	# Display properties
	for property_name in _current_properties:
		var property_value = _current_properties[property_name]
		
		var property_label = Label.new()
		property_label.text = property_name.capitalize() + ": " + str(property_value)
		
		# Color code based on property strength
		if property_value > 1.5:
			property_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		elif property_value > 0.8:
			property_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
		else:
			property_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		
		_property_display.add_child(property_label)

func _calculate_properties(ingredients):
	"""Calculates the properties of the current mixture"""
	var properties = {}
	
	var ingredient_manager = get_node_or_null("/root/IngredientManager")
	if not ingredient_manager:
		return properties
	
	# Get properties from each ingredient
	for ingredient_id in ingredients:
		var ingredient = ingredient_manager.get_ingredient(ingredient_id)
		if ingredient:
			for prop in ingredient.properties:
				var value = ingredient.properties[prop]
				
				if properties.has(prop):
					properties[prop] += value
				else:
					properties[prop] = value
	
	return properties

func _determine_dominant_category():
	"""Determines the dominant category based on properties"""
	var category_scores = {
		"healing": 0,
		"utility": 0,
		"transformation": 0,
		"mind": 0
	}
	
	# Define property categories
	var property_categories = {
		"healing": ["healing", "soothing", "rejuvenation"],
		"utility": ["cleaning", "preservation", "durability", "binding"],
		"transformation": ["strength", "growth", "transformation", "energy"],
		"mind": ["clarity", "focus", "calming", "soothing"]
	}
	
	# Score properties
	for prop in _current_properties:
		var prop_value = _current_properties[prop]
		
		for cat in property_categories:
			if prop in property_categories[cat]:
				category_scores[cat] += prop_value
	
	# Determine highest scoring category
	var highest_score = 0
	var highest_category = "utility"  # Default
	
	for cat in category_scores:
		if category_scores[cat] > highest_score:
			highest_score = category_scores[cat]
			highest_category = cat
	
	return highest_category

func _show_recipe_info(recipe_id):
	"""Shows information about a known recipe"""
	if not _recipe_panel:
		return
	
	var recipe_manager = get_node_or_null("/root/RecipeManager")
	if not recipe_manager:
		return
	
	var recipe = recipe_manager.get_recipe(recipe_id)
	if not recipe:
		return
	
	# Update recipe panel
	var recipe_name_label = _recipe_panel.get_node_or_null("VBoxContainer/RecipeName")
	if recipe_name_label:
		recipe_name_label.text = recipe.name
	
	# Clear ingredients list
	var ingredients_list = _recipe_panel.get_node_or_null("VBoxContainer/IngredientsList")
	if ingredients_list:
		for child in ingredients_list.get_children():
			child.queue_free()
		
		# Add ingredient names
		for ingredient_id in recipe.ingredients:
			var ingredient_manager = get_node_or_null("/root/IngredientManager")
			if ingredient_manager:
				var ingredient = ingredient_manager.get_ingredient(ingredient_id)
				if ingredient:
					var ing_label = Label.new()
					ing_label.text = "• " + ingredient.name
					ingredients_list.add_child(ing_label)
	
	_recipe_panel.visible = true

func _hide_recipe_info():
	"""Hides the recipe info panel"""
	if _recipe_panel:
		_recipe_panel.visible = false

func _play_sound_effect(effect_name):
	"""Plays a sound effect"""
	if not _audio_player:
		return
	
	var sound_path = ""
	
	match effect_name:
		"add_ingredient":
			sound_path = "res://assets/audio/sfx/brewing/add_ingredient.ogg"
		"remove_ingredient":
			sound_path = "res://assets/audio/sfx/brewing/remove_ingredient.ogg"
		"start_brewing":
			sound_path = "res://assets/audio/sfx/brewing/start_brewing.ogg"
		"brewing_complete":
			sound_path = "res://assets/audio/sfx/brewing/brewing_complete.ogg"
		"brewing_failed":
			sound_path = "res://assets/audio/sfx/brewing/brewing_failed.ogg"
		"stir":
			sound_path = "res://assets/audio/sfx/brewing/stir.ogg"
		"cancel_brewing":
			sound_path = "res://assets/audio/sfx/brewing/cancel_brewing.ogg"
	
	if sound_path and ResourceLoader.exists(sound_path):
		_audio_player.stream = load(sound_path)
		_audio_player.play()

func _on_brewing_completed():
	"""Called when brewing timer completes"""
	_is_brewing = false
	set_process(false)
	
	# Get brewing result
	var result = _calculate_brewing_result()
	
	# Play appropriate sound
	if result.success:
		_play_sound_effect("brewing_complete")
	else:
		_play_sound_effect("brewing_failed")
	
	# Reset visuals
	_update_liquid_display(liquid_colors.neutral)
	if _bubble_particles:
		_bubble_particles.emitting = false
	if _steam_particles:
		_steam_particles.emitting = false
	
	if _progress_bar:
		_progress_bar.visible = false
	if _stir_counter:
		_stir_counter.visible = false
	
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
	if _current_recipe_id != "" and not _is_experimental and recipe_manager:
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
			var random_factor = randf_range(-0.1, 0.1)
			
			# Station level bonus
			var level_bonus = (_station_level - 1) * 0.1  # +10% per level
			
			# Specialization bonus
			var spec_bonus = specialization_bonus * 0.05  # +5% per specialization level
			
			# Stir bonus (from interactive brewing)
			var stir_bonus = _brewing_quality_bonus
			
			result.quality = base_quality + random_factor + level_bonus + spec_bonus + stir_bonus
			result.quality = clamp(result.quality, 0.5, 2.0)  # Between 50% and 200%
			
			# Discover the recipe if it was found by experiment
			if not recipe.discovered:
				recipe_manager.discover_recipe(recipe.id)
	elif _is_experimental and recipe_manager:
		# Experimental brewing
		var properties = _current_properties
		
		# Success chance based on property balance
		var value_sum = 0.0
		var count = 0
		for prop in properties:
			value_sum += properties[prop]
			count += 1
		
		var balance = 2.0  # This could be adjusted for difficulty
		var fail_chance = 0.3  # Base 30% chance of failure
		
		# Make it more likely to fail if properties are very unbalanced
		if count > 1 and value_sum > 0:
			var max_value = 0.0
			for prop in properties:
				max_value = max(max_value, properties[prop])
			
			var dominance_ratio = max_value / value_sum
			if dominance_ratio > 0.7:  # One property is very dominant
				fail_chance += 0.2
			elif dominance_ratio < 0.4:  # Properties are well balanced
				fail_chance -= 0.1
		
		# Adjust fail chance based on brewing quality
		fail_chance -= _brewing_quality_bonus * 0.5
		fail_chance = clamp(fail_chance, 0.05, 0.8)  # Between 5% and 80% chance of failure
		
		result.success = !can_fail || (randf() > fail_chance)
		
		if result.success:
			# Create a new experimental recipe
			var experimental_recipe_id = recipe_manager.create_experimental_recipe(properties, _current_ingredients)
			var experimental_recipe = recipe_manager.get_recipe(experimental_recipe_id)
			if experimental_recipe:
				result.potion_id = experimental_recipe.result_id
				result.potion_name = experimental_recipe.name
				
				# Quality calculation
				var base_quality = 1.0
				var random_factor = randf_range(-0.1, 0.2)  # Slightly better chances for experimenting
				var stir_bonus = _brewing_quality_bonus
				
				result.quality = base_quality + random_factor + stir_bonus
				result.quality = clamp(result.quality, 0.6, 2.0)  # Slightly better minimum
		else:
			result.potion_id = "pot_failed_experiment"
			result.potion_name = "Failed Experiment"
			result.quality = 0.5
	else:
		# Default handling for experimental brewing without RecipeManager
		result.success = !can_fail || (randf() > 0.3)  # 30% chance of failure if can_fail is true
		
		if !result.success:
			result.potion_id = "pot_failed_experiment"
			result.potion_name = "Failed Experiment"
			result.quality = 0.5
	
	return result

func _on_slot_input(event, slot_index):
	"""Handles input on ingredient slots"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Left click - interact with slot
			if slot_index < _current_ingredients.size():
				# Remove ingredient if it exists
				remove_ingredient(slot_index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
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

func _on_stir_button_pressed():
	"""Handles stir button press"""
	if _is_brewing:
		stir_cauldron()

func _on_stir_cooldown_complete():
	"""Called when the stir cooldown timer completes"""
	# Re-enable stirring
	pass  # Nothing needed currently as the stir button checks timer directly