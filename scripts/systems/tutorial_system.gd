extends Node
## Tutorial system that guides new players through game mechanics

# Signals
signal tutorial_step_started(step_id)
signal tutorial_step_completed(step_id)
signal tutorial_completed

# Constants
const TUTORIAL_STEPS = {
	"welcome": {
		"title": "Welcome Alchemist!",
		"message": "Welcome to your new alchemy workshop! Let's learn the basics.",
		"target": "",
		"required_action": "acknowledge"
	},
	"open_garden": {
		"title": "Visit the Garden",
		"message": "First, you'll need ingredients. Click the Garden button to gather some.",
		"target": "garden_button",
		"required_action": "click"
	},
	"gather_ingredient": {
		"title": "Gather Ingredients",
		"message": "Click on plants to gather ingredients for your potions.",
		"target": "garden_resource",
		"required_action": "gather",
		"count": 2
	},
	"return_workshop": {
		"title": "Return to Workshop",
		"message": "Great! Now return to your workshop to brew a potion.",
		"target": "workshop_button",
		"required_action": "click"
	},
	"open_inventory": {
		"title": "Open Inventory",
		"message": "Click the inventory button to see what you've gathered.",
		"target": "inventory_button",
		"required_action": "click"
	},
	"add_ingredient": {
		"title": "Add to Cauldron",
		"message": "Drag ingredients to the cauldron or click 'Use in Brewing'.",
		"target": "cauldron_slot",
		"required_action": "add_ingredient",
		"count": 2
	},
	"brew_potion": {
		"title": "Brew Your First Potion",
		"message": "Click the Brew button to create your first potion!",
		"target": "brew_button",
		"required_action": "click"
	},
	"complete": {
		"title": "Tutorial Complete!",
		"message": "You've learned the basics! Keep experimenting with different ingredient combinations to discover new recipes.",
		"target": "",
		"required_action": "acknowledge"
	}
}

# Private variables
var _current_step = ""
var _tutorial_active = false
var _progress = {}
var _highlight_node = null
var _tutorial_overlay = null

# Lifecycle methods
func _ready():
	# Connect to game systems
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		# Listen for new game
		game_manager.game_initialized.connect(_on_new_game)
		
	# Create progress dictionary with all steps set to incomplete
	for step_id in TUTORIAL_STEPS:
		_progress[step_id] = false
		
	# Load saved progress if exists
	_load_tutorial_progress()
	
	# Create tutorial highlight node
	_create_highlight_node()

# Public methods
func start_tutorial():
	"""Starts or resumes the tutorial sequence"""
	if _is_tutorial_completed():
		return false
		
	_tutorial_active = true
	
	# Find first incomplete step
	for step_id in TUTORIAL_STEPS:
		if not _progress[step_id]:
			_start_step(step_id)
			break
			
	return true
	
func skip_tutorial():
	"""Marks the tutorial as completed and hides all tutorial elements"""
	_tutorial_active = false
	
	# Mark all steps as complete
	for step_id in TUTORIAL_STEPS:
		_progress[step_id] = true
	
	# Hide any active tutorial UI
	_hide_tutorial_ui()
	
	# Save progress
	_save_tutorial_progress()
	
	tutorial_completed.emit()
	return true
	
func is_step_completed(step_id):
	"""Checks if a specific tutorial step is completed"""
	if _progress.has(step_id):
		return _progress[step_id]
	return false
	
func is_tutorial_active():
	"""Returns whether the tutorial is currently active"""
	return _tutorial_active

# Private methods
func _start_step(step_id):
	"""Starts a specific tutorial step"""
	if not TUTORIAL_STEPS.has(step_id):
		return
		
	_current_step = step_id
	var step = TUTORIAL_STEPS[step_id]
	
	# Connect to needed signals based on required action
	_connect_step_signals(step_id)
	
	# Show tutorial UI for this step
	_show_tutorial_ui(step)
	
	# Highlight target element if specified
	if step.target != "":
		_highlight_target(step.target)
	
	tutorial_step_started.emit(step_id)

func _complete_step(step_id):
	"""Marks a step as complete and advances to the next step"""
	if not TUTORIAL_STEPS.has(step_id):
		return
		
	# Disconnect signals for this step
	_disconnect_step_signals(step_id)
	
	# Mark as complete
	_progress[step_id] = true
	
	# Hide highlight
	_hide_highlight()
	
	tutorial_step_completed.emit(step_id)
	
	# Save progress
	_save_tutorial_progress()
	
	# Check if tutorial is now complete
	if _is_tutorial_completed():
		_tutorial_active = false
		tutorial_completed.emit()
		return
		
	# Find next step
	var found_current = false
	for next_step_id in TUTORIAL_STEPS:
		if found_current and not _progress[next_step_id]:
			# Start next incomplete step
			_start_step(next_step_id)
			return
			
		if next_step_id == step_id:
			found_current = true

func _connect_step_signals(step_id):
	"""Connects to the appropriate signals based on the step's required action"""
	var step = TUTORIAL_STEPS[step_id]
	
	match step.required_action:
		"gather":
			var gathering_system = get_node_or_null("/root/GatheringSystem")
			if gathering_system:
				gathering_system.resource_gathered.connect(_on_resource_gathered)
			
		"add_ingredient":
			var workshop = get_node_or_null("/root/Main/Workshop")
			if workshop and workshop.has_node("Stations/Cauldron"):
				workshop.get_node("Stations/Cauldron").ingredient_added.connect(_on_ingredient_added)
			
		"click":
			# We'll handle this when highlighting the target
			pass
			
		"acknowledge":
			# This is handled by the tutorial UI itself
			pass

func _disconnect_step_signals(step_id):
	"""Disconnects signals that were connected for this step"""
	var step = TUTORIAL_STEPS[step_id]
	
	match step.required_action:
		"gather":
			var gathering_system = get_node_or_null("/root/GatheringSystem")
			if gathering_system and gathering_system.is_connected("resource_gathered", _on_resource_gathered):
				gathering_system.resource_gathered.disconnect(_on_resource_gathered)
			
		"add_ingredient":
			var workshop = get_node_or_null("/root/Main/Workshop")
			if workshop and workshop.has_node("Stations/Cauldron"):
				var cauldron = workshop.get_node("Stations/Cauldron")
				if cauldron.is_connected("ingredient_added", _on_ingredient_added):
					cauldron.ingredient_added.disconnect(_on_ingredient_added)

func _highlight_target(target_id):
	"""Highlights the target UI element or game object"""
	_hide_highlight()
	
	var target_node = _find_target_node(target_id)
	if not target_node:
		return
	
	# Position highlight around target
	if _highlight_node:
		_highlight_node.global_position = target_node.global_position
		if target_node is Control:
			_highlight_node.size = target_node.size
		elif target_node is Node2D and target_node.has_node("CollisionShape2D"):
			var shape = target_node.get_node("CollisionShape2D").shape
			if shape is CircleShape2D:
				_highlight_node.size = Vector2(shape.radius * 2, shape.radius * 2)
			elif shape is RectangleShape2D:
				_highlight_node.size = shape.size  # Changed from extents to size in Godot 4
		
		_highlight_node.visible = true
		
		# If this is a clickable target, connect to its pressed signal
		if TUTORIAL_STEPS[_current_step].required_action == "click":
			if target_node is BaseButton:
				if not target_node.is_connected("pressed", _on_target_clicked):
					target_node.pressed.connect(_on_target_clicked)

func _hide_highlight():
	"""Hides the highlight node"""
	if _highlight_node:
		_highlight_node.visible = false
		
	# Disconnect any temporary signals
	var current_target = ""
	if TUTORIAL_STEPS.has(_current_step):
		current_target = TUTORIAL_STEPS[_current_step].target
	
	if current_target != "":
		var target_node = _find_target_node(current_target)
		if target_node is BaseButton and target_node.is_connected("pressed", _on_target_clicked):
			target_node.pressed.disconnect(_on_target_clicked)

func _find_target_node(target_id):
	"""Finds a node based on its tutorial target ID"""
	match target_id:
		"garden_button":
			return get_node_or_null("/root/Main/UILayer/HUD/BottomBar/NavButtons/GardenButton")
		"workshop_button":
			return get_node_or_null("/root/Main/UILayer/HUD/BottomBar/NavButtons/WorkshopButton")
		"inventory_button":
			return get_node_or_null("/root/Main/UILayer/HUD/BottomBar/InventoryButton")
		"cauldron_slot":
			var cauldron = get_node_or_null("/root/Main/Workshop/Stations/Cauldron")
			if cauldron and cauldron.has_node("IngredientSlots/Slot1"):
				return cauldron.get_node("IngredientSlots/Slot1")
		"brew_button":
			var cauldron = get_node_or_null("/root/Main/Workshop/Stations/Cauldron")
			if cauldron:
				return cauldron.get_node("BrewButton")
		"garden_resource":
			# Find the first visible resource in the garden
			var garden = get_node_or_null("/root/Main/GatheringAreas/Garden")
			if garden and garden.has_node("ResourceNodes"):
				for child in garden.get_node("ResourceNodes").get_children():
					if child.visible:
						return child
	
	return null

func _create_highlight_node():
	"""Creates a highlight node to draw attention to tutorial targets"""
	_highlight_node = Panel.new()
	_highlight_node.visible = false
	
	# Style the highlight
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.8, 0.3, 0.2)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.8, 0.3, 0.8)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	
	_highlight_node.add_theme_stylebox_override("panel", style)
	
	# Add to UI layer
	var ui_layer = get_node_or_null("/root/Main/UILayer")
	if ui_layer:
		ui_layer.add_child(_highlight_node)
		
		# Make sure it's below other UI elements
		_highlight_node.z_index = -1
		
		# Set it to mouse filter pass so it doesn't block interaction
		_highlight_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _show_tutorial_ui(step):
	"""Shows the tutorial UI with instructions for the current step"""
	# Find or create tutorial overlay
	if not _tutorial_overlay:
		_tutorial_overlay = Panel.new()
		_tutorial_overlay.name = "TutorialOverlay"
		_tutorial_overlay.size = Vector2(300, 150)
		_tutorial_overlay.position = Vector2(20, 100)  # Position near top-left
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.2, 0.9)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.3, 0.7, 0.8, 1.0)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_right = 10
		style.corner_radius_bottom_left = 10
		
		_tutorial_overlay.add_theme_stylebox_override("panel", style)
		
		# Add to UI layer
		var ui_layer = get_node_or_null("/root/Main/UILayer")
		if ui_layer:
			ui_layer.add_child(_tutorial_overlay)
			
			# Create content container
			var container = VBoxContainer.new()
			container.name = "Content"
			container.anchor_right = 1.0
			container.anchor_bottom = 1.0
			container.margin_left = 10
			container.margin_top = 10
			container.margin_right = -10
			container.margin_bottom = -10
			_tutorial_overlay.add_child(container)
			
			# Title label
			var title = Label.new()
			title.name = "Title"
			title.add_theme_font_size_override("font_size", 18)
			title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
			container.add_child(title)
			
			# Message label
			var message = Label.new()
			message.name = "Message"
			message.autowrap_mode = 3  # Enable text wrapping
			message.size_flags_vertical = Control.SIZE_EXPAND_FILL
			container.add_child(message)
			
			# Next button for acknowledgment
			var button = Button.new()
			button.name = "NextButton"
			button.text = "Next"
			button.pressed.connect(_on_tutorial_next_pressed)
			container.add_child(button)
	
	# Update content with step info
	var content = _tutorial_overlay.get_node("Content")
	content.get_node("Title").text = step.title
	content.get_node("Message").text = step.message
	
	# Show/hide next button based on required action
	content.get_node("NextButton").visible = (step.required_action == "acknowledge")
	
	_tutorial_overlay.visible = true

func _hide_tutorial_ui():
	"""Hides the tutorial overlay"""
	if _tutorial_overlay:
		_tutorial_overlay.visible = false

func _is_tutorial_completed():
	"""Checks if all tutorial steps are completed"""
	for step_id in _progress:
		if not _progress[step_id]:
			return false
	return true

func _save_tutorial_progress():
	"""Saves tutorial progress to GameManager"""
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		# Add tutorial progress to GameManager's save data
		# This would need to be implemented in GameManager
		if game_manager.has_method("save_game"):
			game_manager.save_game()

func _load_tutorial_progress():
	"""Loads tutorial progress from GameManager"""
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		# You would implement this based on your save system
		pass

# Signal handlers
func _on_new_game():
	"""Called when a new game is started"""
	# Reset progress
	for step_id in TUTORIAL_STEPS:
		_progress[step_id] = false
	
	# Start tutorial automatically for new games
	call_deferred("start_tutorial")

func _on_resource_gathered(_resource_id, _quantity, _quality):
	"""Called when a resource is gathered during the gather step"""
	if _current_step == "gather_ingredient":
		# Complete this step if we've gathered enough
		_complete_step(_current_step)

func _on_ingredient_added(_slot_index, _ingredient_id):
	"""Called when an ingredient is added to the cauldron"""
	if _current_step == "add_ingredient":
		# Complete this step
		_complete_step(_current_step)

func _on_target_clicked():
	"""Called when the highlighted target is clicked"""
	if TUTORIAL_STEPS[_current_step].required_action == "click":
		# Complete this step
		_complete_step(_current_step)

func _on_tutorial_next_pressed():
	"""Called when the Next button is pressed on acknowledgment steps"""
	if TUTORIAL_STEPS[_current_step].required_action == "acknowledge":
		# Complete this step
		_complete_step(_current_step)
