# Alchemy Workshop - Code Guidelines

## Table of Contents
1. [Introduction](#introduction)
2. [Code Structure](#code-structure)
3. [Naming Conventions](#naming-conventions)
4. [Documentation](#documentation)
5. [Performance Considerations](#performance-considerations)
6. [Versioning and Git Workflow](#versioning-and-git-workflow)
7. [Testing Guidelines](#testing-guidelines)
8. [Platform-Specific Considerations](#platform-specific-considerations)
9. [Asset Integration](#asset-integration)
10. [Accessibility](#accessibility)

## Introduction

This document outlines the coding standards and best practices for the Alchemy Workshop game project. Following these guidelines will ensure code consistency, readability, and maintainability as the project scales from MVP through early access to full release.

### Project Goals

- Create a minimalist yet expressive idle/incremental alchemy crafting game
- Maintain performance on mid-range mobile devices
- Support flexible expansion of game systems (ingredients, recipes, etc.)
- Enable smooth transition between development phases

### Godot-Specific Guidelines

Since Alchemy Workshop is being developed in Godot, these guidelines are tailored to GDScript and Godot's architecture.

## Code Structure

### Script Organization

1. **Extends declaration**: Always at the top of the script
2. **Class documentation**: Brief description of the script's purpose
3. **Signal declarations**: All signals grouped together
4. **Constants**: Defined next, using UPPER_SNAKE_CASE
5. **Exported variables**: Group user-configurable properties
6. **Private variables**: Internal state variables
7. **Onready variables**: References to child nodes
8. **Lifecycle methods**: _init(), _ready(), _process(), _physics_process()
9. **Signal handlers**: Methods connected to signals
10. **Public methods**: Methods called by other scripts
11. **Private methods**: Internal helper methods

Example:
```gdscript
extends Node2D
## Handles the main cauldron brewing station functionality

# Signals
signal brewing_started(recipe_name)
signal brewing_completed(potion_name, quality)
signal brewing_failed(ingredients_used)

# Constants
const MAX_INGREDIENTS = 4
const BREWING_BASE_TIME = 10.0

# Exported variables
export(float) var time_multiplier = 1.0
export(bool) var can_fail = true

# Private variables
var _current_ingredients = []
var _brewing_in_progress = false
var _brewing_timer = 0.0

# Onready variables
onready var _particle_effect = $BrewingParticles
onready var _audio_player = $AudioStreamPlayer

# Lifecycle methods
func _ready():
	_initialize_cauldron()
	
func _process(delta):
	if _brewing_in_progress:
		_update_brewing(delta)

# Signal handlers
func _on_ingredient_dropped(ingredient_data):
	add_ingredient(ingredient_data)

# Public methods
func add_ingredient(ingredient_data):
	if _current_ingredients.size() >= MAX_INGREDIENTS:
		return false
	_current_ingredients.append(ingredient_data)
	return true

func start_brewing():
	if _current_ingredients.empty():
		return false
	
	_brewing_in_progress = true
	_brewing_timer = BREWING_BASE_TIME * time_multiplier
	emit_signal("brewing_started", _get_potential_recipe_name())
	_particle_effect.emitting = true
	_audio_player.play()
	return true

# Private methods
func _initialize_cauldron():
	_particle_effect.emitting = false

func _update_brewing(delta):
	_brewing_timer -= delta
	if _brewing_timer <= 0:
		_complete_brewing()

func _complete_brewing():
	_brewing_in_progress = false
	_particle_effect.emitting = false
	var result = _calculate_brewing_result()
	emit_signal("brewing_completed", result.name, result.quality)
	_current_ingredients.clear()

func _calculate_brewing_result():
	# Implementation details
	return { "name": "Health Potion", "quality": 1 }

func _get_potential_recipe_name():
	# Implementation details
	return "Unknown Concoction"
```

### Resource Loading

1. Use preload for frequently accessed resources:
```gdscript
const POTION_SCENE = preload("res://scenes/items/potion.tscn")
```

2. Use load for conditionally needed resources:
```gdscript
var selected_theme = load("res://assets/themes/" + theme_name + ".tres")
```

3. Use ResourceLoader for non-blocking loading of large assets:
```gdscript
ResourceLoader.load_interactive("res://assets/audio/music/ambient_workshop.ogg")
```

### Node Structure

1. Use PascalCase for node names in the editor
2. Group related nodes with appropriate containers
3. Use meaningful names that reflect the node's purpose
4. Keep scene tree depth reasonable (avoid deep nesting)

Example scene structure for a brewing station:
```
BrewingStation (Node2D)
|-- Visuals (Node2D)
|   |-- Background (Sprite)
|   |-- Cauldron (Sprite)
|   |-- LiquidDisplay (Sprite)
|   |-- BrewingParticles (ParticleSystem)
|-- Colliders (Node2D)
|   |-- IngredientDropArea (Area2D)
|   |-- InteractionArea (Area2D)
|-- Audio (Node)
|   |-- BrewingSound (AudioStreamPlayer)
|   |-- CompletionSound (AudioStreamPlayer)
|   |-- FailureSound (AudioStreamPlayer)
|-- UI (Control)
|   |-- ProgressBar (TextureProgress)
|   |-- RecipeDisplay (Label)
```

## Naming Conventions

### General Rules

1. Be descriptive but concise
2. Avoid abbreviations unless widely understood (UI, NPC, etc.)
3. Use English for all code, comments, and documentation

### Specific Conventions

1. **Scripts**: snake_case.gd (e.g., cauldron_station.gd, ingredient_manager.gd)
2. **Classes**: PascalCase (e.g., class_name PotionRecipe)
3. **Functions/Methods**: snake_case (e.g., brew_potion(), get_ingredient_properties())
4. **Variables**:
   - snake_case for regular variables (e.g., brewing_time, current_potions)
   - _snake_case for private/internal variables (e.g., _ingredients_list, _is_brewing)
5. **Constants**: UPPER_SNAKE_CASE (e.g., MAX_INGREDIENTS, BREWING_BASE_TIME)
6. **Signals**: snake_case verbs, often in past tense (e.g., brewing_completed, ingredient_added)
7. **Nodes**: PascalCase in the scene tree (e.g., BrewingParticles, IngredientSlot)
8. **Files and Resources**:
   - Scenes: snake_case.tscn (e.g., cauldron.tscn, main_menu.tscn)
   - Resources: snake_case.tres (e.g., main_theme.tres, potion_liquid.material)

## Documentation

### Script Documentation

Each script should begin with a brief comment describing its purpose:

```gdscript
extends Node
## Main manager for the ingredient system
## Handles ingredient spawning, properties, and lifecycle
```

### Function Documentation

Document public functions and complex private functions:

```gdscript
## Attempts to combine ingredients according to recipe rules
## Returns a dictionary with success status and resulting potion data
## Parameters:
## - ingredients: Array of ingredient IDs to combine
## - brewing_method: String indicating brewing method (careful, standard, rapid)
func combine_ingredients(ingredients, brewing_method):
	# Implementation
	return result
```

### Type Hints

Use GDScript type hints for clarity and editor assistance:

```gdscript
func calculate_potion_quality(base_quality: int, ingredient_freshness: float) -> int:
	return int(base_quality * ingredient_freshness)
```

### Data Structure Comments

For complex data structures, include a comment explaining the format:

```gdscript
# Recipe data structure:
# {
#   "id": String - unique identifier,
#   "name": String - display name,
#   "ingredients": Array of Strings - ingredient IDs,
#   "properties": Dictionary - resulting potion properties,
#   "difficulty": int - brewing difficulty level,
#   "discovered": bool - whether player has discovered this recipe
# }
var recipes = {}
```

## Performance Considerations

### Mobile Optimization

1. **Limit node count**: Keep scenes lightweight, especially for mobile
2. **Use object pooling**: Pre-instantiate commonly used objects (e.g., ingredient sprites)
3. **Throttle processing**: Not everything needs to update every frame
4. **Limit particle effects**: Use them sparingly and with reduced particle counts on mobile

Example of object pooling:
```gdscript
const POOL_SIZE = 20
var _potion_pool = []

func _ready():
	# Populate pool
	for i in range(POOL_SIZE):
		var potion = POTION_SCENE.instance()
		potion.visible = false
		add_child(potion)
		_potion_pool.append(potion)

func get_potion_from_pool():
	for potion in _potion_pool:
		if not potion.visible:
			potion.visible = true
			return potion
	# If no available potions, create new one
	var new_potion = POTION_SCENE.instance()
	add_child(new_potion)
	_potion_pool.append(new_potion)
	return new_potion
```

### Data Management

1. **Use resource files**: Store game data in .tres files for efficient loading
2. **Lazy loading**: Only load data when needed
3. **Separate static and dynamic data**: Don't save unchanged data

Example of lazy loading ingredients by category:
```gdscript
var _loaded_categories = {}

func get_ingredients_by_category(category):
	if not _loaded_categories.has(category):
		var file_path = "res://data/ingredients_%s.json" % category
		var file = File.new()
		if file.file_exists(file_path):
			file.open(file_path, File.READ)
			var json = JSON.parse(file.get_as_text())
			file.close()
			if json.error == OK:
				_loaded_categories[category] = json.result
			else:
				push_error("Failed to parse ingredients JSON: %s" % category)
				_loaded_categories[category] = []
		else:
			push_error("Missing ingredients file: %s" % file_path)
			_loaded_categories[category] = []
	
	return _loaded_categories[category]
```

### Timing and Processing

1. **Use _process() sparingly**: Only for visuals that need per-frame updates
2. **Use _physics_process() for gameplay logic**: More consistent timing
3. **Use timers for delayed events** rather than counters in _process()
4. **Consider using idle time**: process_idle() for background tasks

Example of timer usage:
```gdscript
func start_ingredient_regeneration(ingredient_id):
	var regen_data = _ingredient_regen_times[ingredient_id]
	var timer = Timer.new()
	timer.wait_time = regen_data.base_time * _regen_time_multiplier
	timer.one_shot = true
	timer.connect("timeout", self, "_on_regeneration_complete", [ingredient_id, timer])
	add_child(timer)
	timer.start()

func _on_regeneration_complete(ingredient_id, timer):
	_respawn_ingredient(ingredient_id)
	timer.queue_free()
```

## Versioning and Git Workflow

### Branch Structure

- **main**: Production-ready code
- **development**: Integration branch for features
- **feature/feature-name**: Individual feature branches
- **bugfix/bug-description**: Bug fix branches
- **release/version-number**: Release preparation branches

### Commit Guidelines

1. **Use clear commit messages**: Begin with a verb in present tense
   - "Add brewing animation to cauldron"
   - "Fix ingredient counter display bug"
   - "Update villager dialogue system"

2. **Keep commits focused**: One logical change per commit

3. **Structure commit messages**:
   ```
   Short summary (50 chars or less)

   More detailed explanatory text, if necessary. Wrap it to about 72
   characters. The blank line separating the summary from the body is
   critical.
   
   - Bullet points are okay
   - Use a hyphen or asterisk followed by a space
   ```

### Version Numbering

Follow Semantic Versioning (SemVer):
- **Major.Minor.Patch** (e.g., 0.1.0, 1.2.3)
- Increment Major for incompatible API changes
- Increment Minor for new features in a backward-compatible manner
- Increment Patch for backward-compatible bug fixes

For development phases:
- Pre-MVP: 0.0.x
- MVP: 0.1.0
- Early Access: 0.x.y
- Full Release: 1.0.0

### Git Best Practices

1. **Pull before pushing**: Always pull recent changes before pushing
2. **Resolve conflicts locally**: Handle merge conflicts on your machine
3. **Review changes before committing**: Use `git diff` to check changes
4. **Use .gitignore properly**: Exclude build files, temporary files, and editor metadata

## Testing Guidelines

### Manual Testing

1. **Feature testing**: Verify each feature works as specified
2. **Integration testing**: Verify features work together
3. **Regression testing**: Verify that bug fixes don't break existing functionality
4. **Platform testing**: Test on target platforms (iOS, Android)

### Automated Testing

1. **Unit tests**: Use Godot's built-in test framework for critical systems
2. **Test data**: Create specific test scenarios for complex systems

Example unit test:
```gdscript
extends "res://addons/gut/test.gd"

func test_potion_creation():
	var brewing_system = BrewingSystem.new()
	var ingredients = ["lavender", "quartz_dust", "pure_water"]
	var result = brewing_system.combine_ingredients(ingredients, "standard")
	assert_true(result.success, "Should successfully create a potion")
	assert_eq(result.potion.name, "Clarity Potion", "Should create a Clarity Potion")
```

### Test Checklist

Create a test checklist for major features, including:
- Normal operation cases
- Edge cases
- Error handling
- Performance under load

## Platform-Specific Considerations

### Mobile-First Design

1. **Touch-friendly UI**: Ensure UI elements are appropriately sized for touch
2. **Portrait orientation**: Optimize for vertical phone screens
3. **Battery awareness**: Implement power-saving mode for background processing
4. **Memory limits**: Be aware of lower memory limits on mobile devices

### Platform Detection

Use Godot's OS class to adapt to different platforms:

```gdscript
func _ready():
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		_configure_mobile_settings()
	else:
		_configure_desktop_settings()

func _configure_mobile_settings():
	$UI/Buttons.rect_min_size = Vector2(120, 120)  # Larger buttons for touch
	Engine.target_fps = 30  # Lower FPS to save battery
```

### Input Handling

Adapt input handling based on platform:

```gdscript
func _input(event):
	if event is InputEventScreenTouch and event.pressed:
		_handle_touch(event.position)
	elif event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		_handle_click(event.position)

func _handle_touch(position):
	# Mobile-specific touch handling
	pass

func _handle_click(position):
	# Desktop-specific click handling
	pass
```

## Asset Integration

### Asset Naming Conventions

1. **Textures**: snake_case_type.png (e.g., lavender_ingredient.png, cauldron_station.png)
2. **Audio**: snake_case_category_descriptor.ogg (e.g., sfx_brewing_bubble.ogg, music_spring_theme.ogg)
3. **Animations**: snake_case_action.tres (e.g., cauldron_brewing.tres, potion_sparkle.tres)

### Asset Organization

Follow the project structure for organizing assets:
- `/assets/images/ingredients/common_plants/lavender.png`
- `/assets/audio/sfx/brewing/bubble_loop.ogg`

### Dynamic Asset Loading

Use dynamic paths for loading assets when appropriate:

```gdscript
func load_ingredient_texture(ingredient_id):
	var category = _get_ingredient_category(ingredient_id)
	var path = "res://assets/images/ingredients/%s/%s.png" % [category, ingredient_id]
	return load(path)
```

## Accessibility

### Color Considerations

1. **Color blindness**: Don't rely solely on color for critical information
2. **Text contrast**: Ensure text has sufficient contrast against backgrounds
3. **Alternate indicators**: Use shapes, patterns, or icons in addition to colors

### Audio Cues

1. **Separate volume controls**: Allow players to adjust different audio types
2. **Visual feedback**: Accompany audio cues with visual feedback

### Interface Scaling

Implement UI scaling for different device sizes and accessibility needs:

```gdscript
var ui_scale = 1.0

func set_ui_scale(scale):
	ui_scale = scale
	$UI.rect_scale = Vector2(scale, scale)
	# Adjust positions to compensate for scaling
	# ...
```

### Font Size Options

Allow players to adjust text size:

```gdscript
func set_font_size(size_option):
	var sizes = {
		"small": 14,
		"medium": 18,
		"large": 24,
		"extra_large": 32
	}
	
	var theme = $UI.theme.duplicate()
	var font = theme.get_font("font", "Label").duplicate()
	font.size = sizes[size_option]
	theme.set_font("font", "Label", font)
	$UI.theme = theme
```

## Conclusion

These guidelines should be treated as a living document and updated as the project evolves. Regular code reviews should be conducted to ensure adherence to these standards and to identify areas where the guidelines need modification.

Remember that the ultimate goal is to create maintainable, efficient code that enables the team to deliver the Alchemy Workshop experience as envisioned in the design documents while maintaining flexibility for future growth.
