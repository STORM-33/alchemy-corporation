extends Node
## Manages the tutorial experience for new players
## Add this script to an autoload in the Project Settings

# Signals
signal tutorial_started
signal tutorial_step_changed(step_number)
signal tutorial_completed
signal tutorial_skipped

# Constants
const TUTORIAL_OVERLAY_SCENE = preload("res://scenes/ui/tutorial_overlay.tscn")

# TutorialStep class to define tutorial steps
class TutorialStep:
	var title: String
	var message: String
	var highlight_node_path: String = ""
	var highlight_size: Vector2 = Vector2(100, 100)
	var pointer_position: Vector2 = Vector2.ZERO
	var popup_text: String = ""
	var wait_for_action: bool = false
	var action_type: String = ""
	var action_target: String = ""
	
	func _init(p_title: String, p_message: String):
		title = p_title
		message = p_message
	
	func with_highlight(node_path: String, size: Vector2 = Vector2(100, 100)):
		highlight_node_path = node_path
		highlight_size = size
		return self
	
	func with_pointer(position: Vector2, text: String = ""):
		pointer_position = position
		popup_text = text
		return self
	
	func with_action(action: String, target: String = ""):
		wait_for_action = true
		action_type = action
		action_target = target
		return self

# Private variables
var _tutorial_steps = []
var _current_step = 0
var _tutorial_overlay = null
var _tutorial_completed = false
var _is_tutorial_active = false
var _waiting_for_action = false
var _target_node = null

# Lifecycle methods
func _ready():
	# Create tutorial steps
	_initialize_tutorial_steps()

# Public methods
func start_tutorial():
	"""Starts the tutorial from the beginning"""
	if _is_tutorial_active:
		return
	
	_is_tutorial_active = true
	_current_step = 0
	_tutorial_completed = false
	
	# Create tutorial overlay
	_create_tutorial_overlay()
	
	# Show first step
	_show_current_step()
	
	tutorial_started.emit()

func next_step():
	"""Advances to the next tutorial step"""
	if not _is_tutorial_active:
		return
	
	_current_step += 1
	
	if _current_step >= _tutorial_steps.size():
		_complete_tutorial()
		return
	
	_show_current_step()
	tutorial_step_changed.emit(_current_step)

func skip_tutorial():
	"""Skips the tutorial"""
	if not _is_tutorial_active:
		return
	
	_is_tutorial_active = false
	_waiting_for_action = false
	
	if _tutorial_overlay:
		_tutorial_overlay.queue_free()
		_tutorial_overlay = null
	
	tutorial_skipped.emit()

func is_tutorial_active():
	"""Returns whether the tutorial is currently active"""
	return _is_tutorial_active

func is_tutorial_completed():
	"""Returns whether the tutorial has been completed"""
	return _tutorial_completed

func trigger_action(action_type, target_name = ""):
	"""Called when a player performs a tutorial-relevant action"""
	if not _is_tutorial_active or not _waiting_for_action:
		return
	
	var current_step = _tutorial_steps[_current_step]
	
	if action_type == current_step.action_type:
		if current_step.action_target.is_empty() or current_step.action_target == target_name:
			_waiting_for_action = false
			next_step()

# Private methods
func _initialize_tutorial_steps():
	"""Creates all tutorial steps"""
	_tutorial_steps = [
		TutorialStep.new(
			"Welcome, Alchemist!",
			"Welcome to your new alchemy workshop! Let's learn the basics of brewing potions and running your business."
		),
		
		TutorialStep.new(
			"Your Workshop",
			"This is your workshop. The cauldron is where you'll brew your potions. Let's start by gathering some ingredients."
		).with_highlight("/root/Main/Workshop/Stations/Cauldron", Vector2(200, 200)),
		
		TutorialStep.new(
			"Gathering Ingredients",
			"First, let's visit the garden to gather some ingredients. Click the 'Garden' button to visit your garden."
		).with_highlight("/root/Main/UILayer/HUD/BottomBar/NavButtons/GardenButton", Vector2(100, 50))
		.with_pointer(Vector2(0, -30), "Click here")
		.with_action("navigation", "garden"),
		
		TutorialStep.new(
			"Collecting Herbs",
			"Great! Now click on any plant to collect it. You need ingredients to make potions."
		).with_action("gather", ""),
		
		TutorialStep.new(
			"Return to Workshop",
			"Good job! Now let's return to your workshop to start brewing. Click the 'Workshop' button."
		).with_highlight("/root/Main/UILayer/HUD/BottomBar/NavButtons/WorkshopButton", Vector2(100, 50))
		.with_pointer(Vector2(0, -30), "Click here")
		.with_action("navigation", "workshop"),
		
		TutorialStep.new(
			"Adding Ingredients",
			"Click on the cauldron to select it, then open your inventory by clicking the 'Inventory' button."
		).with_highlight("/root/Main/UILayer/HUD/BottomBar/InventoryButton", Vector2(100, 50))
		.with_pointer(Vector2(0, -30), "Click here")
		.with_action("open_inventory", ""),
		
		TutorialStep.new(
			"Brewing Process",
			"Drag ingredients from your inventory to the cauldron. Once you've added ingredients, click the 'Brew' button to start brewing."
		).with_highlight("/root/Main/Workshop/Stations/Cauldron/BrewButton", Vector2(100, 50))
		.with_action("brewing_started", ""),
		
		TutorialStep.new(
			"Your First Potion",
			"Excellent! While brewing, try stirring the cauldron for better quality. Wait for the brewing to complete."
		).with_action("brewing_completed", ""),
		
		TutorialStep.new(
			"Congratulations!",
			"You've created your first potion! As you progress, you'll discover more recipes and unlock advanced brewing techniques. Explore more ingredients in the Garden and Forest, fulfill orders for villagers, and grow your alchemy business!"
		)
	]

func _create_tutorial_overlay():
	"""Creates the tutorial overlay UI"""
	if _tutorial_overlay:
		_tutorial_overlay.queue_free()
	
	_tutorial_overlay = TUTORIAL_OVERLAY_SCENE.instantiate()
	get_tree().root.add_child(_tutorial_overlay)
	
	# Connect signals
	_tutorial_overlay.get_node("TutorialPanel/VBoxContainer/ButtonContainer/NextButton").pressed.connect(_on_next_button_pressed)
	_tutorial_overlay.get_node("TutorialPanel/VBoxContainer/ButtonContainer/SkipButton").pressed.connect(_on_skip_button_pressed)
	_tutorial_overlay.get_node("ConfirmationDialog").confirmed.connect(_on_skip_confirmed)
	_tutorial_overlay.get_node("ConfirmationDialog").canceled.connect(_on_skip_canceled)
	_tutorial_overlay.get_node("CompletionPanel/VBoxContainer/CloseButton").pressed.connect(_on_completion_close_pressed)

func _show_current_step():
	"""Updates the UI to show the current tutorial step"""
	if not _tutorial_overlay or _current_step >= _tutorial_steps.size():
		return
	
	var step = _tutorial_steps[_current_step]
	
	# Update panel content
	var title_label = _tutorial_overlay.get_node("TutorialPanel/VBoxContainer/TitleLabel")
	var step_number = _tutorial_overlay.get_node("TutorialPanel/VBoxContainer/ContentContainer/StepNumber")
	var message_label = _tutorial_overlay.get_node("TutorialPanel/VBoxContainer/ContentContainer/MessageLabel")
	var progress_bar = _tutorial_overlay.get_node("TutorialPanel/VBoxContainer/ProgressBar")
	
	title_label.text = step.title
	step_number.text = "Step " + str(_current_step + 1) + " of " + str(_tutorial_steps.size())
	message_label.text = step.message
	progress_bar.max_value = _tutorial_steps.size()
	progress_bar.value = _current_step + 1
	
	# Show or hide highlight rect
	var highlight_rect = _tutorial_overlay.get_node("HighlightRect")
	if step.highlight_node_path.is_empty():
		highlight_rect.visible = false
	else:
		_target_node = get_node_or_null(step.highlight_node_path)
		if _target_node:
			# Position highlight over the target
			var global_rect = _get_global_rect(_target_node)
			highlight_rect.size = step.highlight_size
			highlight_rect.position = global_rect.position - Vector2(10, 10)
			highlight_rect.size = global_rect.size + Vector2(20, 20)
			highlight_rect.visible = true
		else:
			highlight_rect.visible = false
	
	# Show or hide pointer
	var pointer = _tutorial_overlay.get_node("PointerArrow")
	var popup_label = _tutorial_overlay.get_node("PopupLabel")
	
	if step.pointer_position == Vector2.ZERO:
		pointer.visible = false
		popup_label.visible = false
	else:
		if _target_node:
			var target_position = _target_node.global_position
			pointer.position = target_position + step.pointer_position
			pointer.rotation = PI  # Point downward by default
			pointer.visible = true
			
			if not step.popup_text.is_empty():
				popup_label.text = step.popup_text
				popup_label.position = pointer.position - Vector2(popup_label.size.x / 2, pointer.get_rect().size.y + popup_label.size.y + 10)
				popup_label.visible = true
			else:
				popup_label.visible = false
		else:
			pointer.visible = false
			popup_label.visible = false
	
	# Set up waiting for action if needed
	_waiting_for_action = step.wait_for_action

func _complete_tutorial():
	"""Completes the tutorial and shows completion screen"""
	_is_tutorial_active = false
	_tutorial_completed = true
	
	if _tutorial_overlay:
		# Hide tutorial panel and show completion panel
		_tutorial_overlay.get_node("TutorialPanel").visible = false
		_tutorial_overlay.get_node("HighlightRect").visible = false
		_tutorial_overlay.get_node("PointerArrow").visible = false
		_tutorial_overlay.get_node("PopupLabel").visible = false
		_tutorial_overlay.get_node("CompletionPanel").visible = true
		
		# Add tutorial reward
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager:
			game_manager.add_gold(50)
	
	tutorial_completed.emit()

func _get_global_rect(node):
	"""Gets the global rectangle of a Control or Node2D"""
	if node is Control:
		return Rect2(node.global_position, node.size)
	elif node is Node2D:
		var bounds = Rect2(Vector2.ZERO, Vector2(100, 100))  # Default size
		if node.has_method("get_rect"):
			bounds = node.get_rect()
		return Rect2(node.global_position - bounds.size/2, bounds.size)
	return Rect2(Vector2.ZERO, Vector2(100, 100))

func _on_next_button_pressed():
	"""Handle next button press"""
	if not _waiting_for_action:
		next_step()

func _on_skip_button_pressed():
	"""Handle skip button press"""
	_tutorial_overlay.get_node("ConfirmationDialog").popup_centered()

func _on_skip_confirmed():
	"""Handle skip confirmation"""
	skip_tutorial()

func _on_skip_canceled():
	"""Handle skip cancellation"""
	# Nothing to do
	pass

func _on_completion_close_pressed():
	"""Handle completion panel close button press"""
	if _tutorial_overlay:
		_tutorial_overlay.queue_free()
		_tutorial_overlay = null
