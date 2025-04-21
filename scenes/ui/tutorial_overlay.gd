extends CanvasLayer
## UI Overlay for the tutorial system

# Onready variables
@onready var _dim_background = $DimBackground
@onready var _tutorial_panel = $TutorialPanel
@onready var _highlight_rect = $HighlightRect
@onready var _pointer_arrow = $PointerArrow
@onready var _popup_label = $PopupLabel
@onready var _confirmation_dialog = $ConfirmationDialog
@onready var _completion_panel = $CompletionPanel

# Lifecycle methods
func _ready():
	# Initialize UI state
	_tutorial_panel.visible = true
	_highlight_rect.visible = false
	_pointer_arrow.visible = false
	_popup_label.visible = false
	_completion_panel.visible = false
	
	# Set layer to top
	layer = 100

# Private methods
func _process(_delta):
	# If we're highlighting a node, update highlight position
	if _highlight_rect.visible and _highlight_rect.get_meta("target_node", null):
		var target_node = _highlight_rect.get_meta("target_node")
		if is_instance_valid(target_node):
			var global_rect = _get_global_rect(target_node)
			_highlight_rect.size = global_rect.size + Vector2(20, 20)
			_highlight_rect.position = global_rect.position - Vector2(10, 10)

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

# Public methods
func set_highlight_target(node):
	"""Sets the node to highlight"""
	if is_instance_valid(node):
		_highlight_rect.set_meta("target_node", node)
		_highlight_rect.visible = true
		
		# Initial position update
		var global_rect = _get_global_rect(node)
		_highlight_rect.size = global_rect.size + Vector2(20, 20)
		_highlight_rect.position = global_rect.position - Vector2(10, 10)
	else:
		_highlight_rect.visible = false

func set_pointer(position, text=""):
	"""Sets the pointer arrow and optional text"""
	_pointer_arrow.position = position
	_pointer_arrow.visible = true
	
	if text.is_empty():
		_popup_label.visible = false
	else:
		_popup_label.text = text
		_popup_label.position = position - Vector2(_popup_label.size.x / 2, _popup_label.size.y + 20)
		_popup_label.visible = true

func hide_pointer():
	"""Hides the pointer and text"""
	_pointer_arrow.visible = false
	_popup_label.visible = false

func update_progress(current, total):
	"""Updates the progress bar"""
	var progress_bar = _tutorial_panel.get_node_or_null("VBoxContainer/ProgressBar")
	if progress_bar:
		progress_bar.max_value = total
		progress_bar.value = current

func update_content(title, step_number, total_steps, message):
	"""Updates the tutorial panel content"""
	var title_label = _tutorial_panel.get_node_or_null("VBoxContainer/TitleLabel")
	var step_label = _tutorial_panel.get_node_or_null("VBoxContainer/ContentContainer/StepNumber")
	var message_label = _tutorial_panel.get_node_or_null("VBoxContainer/ContentContainer/MessageLabel")
	
	if title_label:
		title_label.text = title
	
	if step_label:
		step_label.text = "Step " + str(step_number) + " of " + str(total_steps)
	
	if message_label:
		message_label.text = message
	
	update_progress(step_number, total_steps)

func show_completion_panel(gold_reward=50):
	"""Shows the tutorial completion panel"""
	_tutorial_panel.visible = false
	_highlight_rect.visible = false
	_pointer_arrow.visible = false
	_popup_label.visible = false
	
	# Update reward amount
	var gold_amount = _completion_panel.get_node_or_null("VBoxContainer/RewardContainer/VBoxContainer/HBoxContainer/GoldAmount")
	if gold_amount:
		gold_amount.text = str(gold_reward)
	
	_completion_panel.visible = true

func show_skip_confirmation():
	"""Shows the skip tutorial confirmation dialog"""
	_confirmation_dialog.popup_centered()