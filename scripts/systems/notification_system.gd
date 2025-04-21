extends Node
## Manages in-game notifications
## Add this script to an autoload in the Project Settings

# Constants
const MAX_NOTIFICATIONS = 5
const NOTIFICATION_SCENE = preload("res://scenes/ui/notification.tscn")

# Private variables
var _notification_queue = []
var _active_notifications = []
var _notification_container = null

# Lifecycle methods
func _ready():
	# Wait a moment to allow the UI to initialize
	await get_tree().create_timer(0.5).timeout
	_find_notification_container()

# Public methods
func show_notification(message, duration=3.0, type="normal"):
	"""Shows a notification with the given message and type"""
	_notification_queue.append({
		"message": message,
		"duration": duration,
		"type": type
	})
	
	_process_notification_queue()

func show_success(message, duration=3.0):
	"""Shows a success notification"""
	show_notification(message, duration, "success")

func show_info(message, duration=3.0):
	"""Shows an info notification"""
	show_notification(message, duration, "info")

func show_warning(message, duration=3.0):
	"""Shows a warning notification"""
	show_notification(message, duration, "warning")

func show_error(message, duration=3.0):
	"""Shows an error notification"""
	show_notification(message, duration, "error")

func clear_all_notifications():
	"""Clears all active notifications"""
	for notification in _active_notifications:
		if is_instance_valid(notification):
			notification.queue_free()
	
	_active_notifications.clear()
	_notification_queue.clear()

# Private methods
func _find_notification_container():
	"""Finds the notification container in the scene"""
	# Try to find it at common paths
	var possible_paths = [
		"/root/Main/UILayer/NotificationArea",
		"/root/Main/UILayer/HUD/NotificationArea",
		"/root/Main/UI/NotificationArea"
	]
	
	for path in possible_paths:
		if has_node(path):
			_notification_container = get_node(path)
			break
	
	# If still not found, search for it
	if not _notification_container:
		_notification_container = _find_node_by_name(get_tree().root, "NotificationArea")
	
	# Create a container if none exists
	if not _notification_container:
		push_warning("Notification container not found, creating one")
		_create_notification_container()

func _find_node_by_name(node, name):
	"""Recursively searches for a node with the given name"""
	if node.name == name:
		return node
	
	for child in node.get_children():
		var result = _find_node_by_name(child, name)
		if result:
			return result
	
	return null

func _create_notification_container():
	"""Creates a notification container if none exists"""
	_notification_container = VBoxContainer.new()
	_notification_container.name = "NotificationArea"
	_notification_container.alignment = BoxContainer.ALIGNMENT_END  # Align to bottom
	
	# Set position and size
	_notification_container.anchors_preset = Control.PRESET_TOP_WIDE
	_notification_container.offset_top = 100
	_notification_container.offset_left = 200
	_notification_container.offset_right = -200
	_notification_container.offset_bottom = 300
	
	# Add to the scene (try to add to the appropriate layer)
	var ui_layer = _find_node_by_name(get_tree().root, "UILayer")
	if not ui_layer:
		ui_layer = get_tree().root
	
	ui_layer.add_child(_notification_container)

func _process_notification_queue():
	"""Processes the notification queue"""
	if _notification_queue.empty():
		return
	
	if not _notification_container:
		_find_notification_container()
		if not _notification_container:
			push_error("Notification container not found")
			return
	
	# Check if we can show more notifications
	if _active_notifications.size() >= MAX_NOTIFICATIONS:
		# Remove notifications that are no longer valid
		for i in range(_active_notifications.size() - 1, -1, -1):
			if not is_instance_valid(_active_notifications[i]):
				_active_notifications.remove_at(i)
		
		# Still too many notifications?
		if _active_notifications.size() >= MAX_NOTIFICATIONS:
			return
	
	# Get the next notification
	var notification_data = _notification_queue.pop_front()
	
	# Create notification instance
	var notification = NOTIFICATION_SCENE.instantiate()
	notification.message = notification_data.message
	notification.duration = notification_data.duration
	notification.type = notification_data.type
	
	# Connect signal to remove from active list when finished
	notification.notification_ended.connect(_on_notification_ended.bind(notification))
	
	# Add to container
	_notification_container.add_child(notification)
	_active_notifications.append(notification)
	
	# Process more notifications if available
	if not _notification_queue.empty():
		await get_tree().create_timer(0.2).timeout
		_process_notification_queue()

func _on_notification_ended(notification):
	"""Called when a notification is finished"""
	var index = _active_notifications.find(notification)
	if index >= 0:
		_active_notifications.remove_at(index)
	
	# Process more notifications if any are waiting
	if not _notification_queue.empty():
		await get_tree().create_timer(0.2).timeout
		_process_notification_queue()
