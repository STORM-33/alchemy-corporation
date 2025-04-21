extends Node
## Simple notification system to provide feedback to the player
## Add this script to an autoload in Project Settings

# Signals
signal notification_added(message, type)

# Constants
const NOTIFICATION_TYPES = {
	"normal": Color(0.9, 0.9, 0.9),   # Light gray
	"success": Color(0.4, 0.8, 0.4),  # Green
	"warning": Color(0.9, 0.7, 0.3),  # Orange
	"error": Color(0.9, 0.3, 0.3),    # Red
	"info": Color(0.4, 0.7, 0.9)      # Blue
}

const DEFAULT_DURATION = 3.0  # Default display time in seconds
const MAX_NOTIFICATIONS = 5   # Maximum number of notifications to show at once

# Private variables
var _active_notifications = []
var _hud = null

# Lifecycle methods
func _ready():
	# We'll initialize HUD reference when it becomes available
	call_deferred("_find_hud")

# Public methods
func show_notification(message, type="normal", duration=DEFAULT_DURATION):
	"""
	Shows a notification to the player
	- message: Text to display
	- type: Type of notification (normal, success, warning, error, info)
	- duration: How long to display the notification
	"""
	if message.is_empty():
		return
	
	# Validate notification type
	if not NOTIFICATION_TYPES.has(type):
		type = "normal"
	
	# Create notification data
	var notification = {
		"message": message,
		"type": type,
		"duration": duration,
		"time": Time.get_unix_time_from_system()
	}
	
	# Add to active notifications
	_active_notifications.append(notification)
	
	# Limit the number of active notifications
	while _active_notifications.size() > MAX_NOTIFICATIONS:
		_active_notifications.pop_front()
	
	# Signal that a notification was added
	notification_added.emit(message, type)
	
	# Try to display in HUD if available
	if _hud and _hud.has_method("show_notification"):
		_hud.show_notification(message, duration, type)
	else:
		# Fallback: Print to console
		print("Notification (%s): %s" % [type, message])

func show_success(message, duration=DEFAULT_DURATION):
	"""Shows a success notification"""
	show_notification(message, "success", duration)

func show_warning(message, duration=DEFAULT_DURATION):
	"""Shows a warning notification"""
	show_notification(message, "warning", duration)

func show_error(message, duration=DEFAULT_DURATION):
	"""Shows an error notification"""
	show_notification(message, "error", duration)

func show_info(message, duration=DEFAULT_DURATION):
	"""Shows an info notification"""
	show_notification(message, "info", duration)

func clear_notifications():
	"""Clears all active notifications"""
	_active_notifications.clear()

# Private methods
func _find_hud():
	"""Attempts to find the HUD in the scene"""
	var hud_path = "/root/Main/UILayer/HUD"
	if has_node(hud_path):
		_hud = get_node(hud_path)
	else:
		# Try again later
		await get_tree().create_timer(1.0).timeout
		_find_hud()
