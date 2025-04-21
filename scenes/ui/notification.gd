extends PanelContainer
## Visual notification component

# Signal when notification disappears
signal notification_ended

# Notification properties
@export var message: String = ""
@export var duration: float = 3.0
@export var type: String = "normal"

# Type colors
var type_colors = {
	"normal": Color(0.396078, 0.65098, 0.847059, 1),  # Blue
	"success": Color(0.396078, 0.65098, 0.247059, 1), # Green
	"warning": Color(0.847059, 0.647059, 0.196078, 1), # Orange
	"error": Color(0.847059, 0.247059, 0.196078, 1),  # Red
	"info": Color(0.396078, 0.447059, 0.847059, 1)    # Purple
}

# Onready variables
@onready var _label = $MarginContainer/Label
@onready var _animation_player = $AnimationPlayer
@onready var _panel_style = get_theme_stylebox("panel").duplicate()

# Lifecycle methods
func _ready():
	# Set up the notification
	if message:
		_label.text = message
	
	# Set the animation duration
	if duration != 3.0 and _animation_player:
		var animation = _animation_player.get_animation("fade")
		if animation:
			animation.track_set_key_value(0, 2, Color(1, 1, 1, 1))  # Keep full opacity until duration
			animation.track_set_key_time(0, 2, duration)
			animation.track_set_key_time(0, 3, duration + 0.5)
			animation.track_set_key_time(1, 0, duration + 0.5)
			animation.length = duration + 0.5
	
	# Set color based on type
	if type in type_colors:
		_panel_style.border_color = type_colors[type]
		add_theme_stylebox_override("panel", _panel_style)
	
	# Connect to animation finished signal
	if _animation_player:
		_animation_player.animation_finished.connect(_on_animation_finished)
		_animation_player.play("fade")

# Set the notification message
func set_message(new_message):
	message = new_message
	if _label:
		_label.text = message

# Set the notification type and update styling
func set_type(new_type):
	if new_type in type_colors:
		type = new_type
		if _panel_style:
			_panel_style.border_color = type_colors[type]
			add_theme_stylebox_override("panel", _panel_style)

# Handle animation finished
func _on_animation_finished(_anim_name):
	notification_ended.emit()
	queue_free()

# Handle click to dismiss
func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Skip to end of animation to dismiss
		if _animation_player and _animation_player.is_playing():
			_animation_player.seek(duration + 0.4)
