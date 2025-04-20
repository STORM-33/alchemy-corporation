extends Node2D
## Garden area for gathering common plant ingredients

# Signals
signal resource_clicked(resource_id, node_id)
signal area_entered

# Exported variables
@export var available_resources:  = [
	"ing_lavender", 
	"ing_mint", 
	"ing_sage", 
	"ing_chamomile"
]

@export var spawn_on_ready: bool = true
@export var initial_resource_count: int = 3

# Onready variables
@onready var _resource_nodes = $ResourceNodes
@onready var _spawn_points = $SpawnPoints

# Private variables
var _area_initialized = false
var _area_id = "garden"

# Lifecycle methods
func _ready():
	emit_signal("area_entered")
	
	# Initialize with the gathering system
	var gathering_system = get_node_or_null("/root/GatheringSystem")
	if gathering_system and spawn_on_ready:
		_initialize_with_gathering_system(gathering_system)

# Public methods
func get_spawn_positions():
	"""Returns an array of all spawn point positions"""
	var positions = []
	
	for child in _spawn_points.get_children():
		if child is Marker2D:
			positions.append(child.global_position)
	
	return positions

func spawn_resource(resource_id, position):
	"""
	Manually spawns a resource at the given position
	Primarily for testing, normally handled by GatheringSystem
	"""
	var gathering_system = get_node_or_null("/root/GatheringSystem")
	if not gathering_system:
		return ""
	
	var resource_node = gathering_system.spawn_resource_at_position(
		resource_id, 
		_area_id, 
		position
	)
	
	return resource_node

# Private methods
func _initialize_with_gathering_system(gathering_system):
	"""Initializes this area with the gathering system"""
	if _area_initialized:
		return
	
	# Get all spawn positions
	var spawn_positions = get_spawn_positions()
	if spawn_positions.empty():
		push_error("Garden has no spawn positions!")
		return
	
	# Tell the gathering system about this area
	gathering_system.initialize_gathering_area(
		_area_id,
		spawn_positions,
		_get_initial_resources(initial_resource_count)
	)
	
	# Connect signals to be notified when resources are spawned
	gathering_system.connect("resource_spawned", self, "_on_resource_spawned")
	
	_area_initialized = true

func _get_initial_resources(count):
	"""Randomly selects resources to spawn initially"""
	if available_resources.is_empty():
		return []
	
	var resources = []
	var remaining = min(count, available_resources.size())
	
	# Create a copy so we don't modify the original
	var resource_pool = available_resources.duplicate()
	
	while remaining > 0 and not resource_pool.empty():
		# Pick random resource
		var index = randi() % resource_pool.size()
		var resource = resource_pool[index]
		
		resources.append(resource)
		resource_pool.remove(index)
		remaining -= 1
	
	return resources

func _on_resource_spawned(resource_id, node_id):
	"""Called when a resource is spawned by the gathering system"""
	# Actual node creation is handled by the gathering system
	# This is just to hook up any additional functionality if needed
	pass

func _on_resource_clicked(node_id):
	"""Called when a resource node is clicked"""
	var gathering_system = get_node_or_null("/root/GatheringSystem")
	if gathering_system:
		var result = gathering_system.gather_resource(node_id)
		if result.success:
			emit_signal("resource_clicked", result.resource_id, node_id)
