extends Area2D
## Represents a gatherable resource in the world
## Attach this script to a resource node scene

# Signals
signal resource_gathered(node_id)
signal resource_clicked(node_id)

# Exported variables
@export var resource_id: String = ""  # The type of resource
@export var node_id: String = ""  # Unique identifier for this specific node
@export var resource_texture: Texture2D = null  # Optional default texture
@export var sprite_scale: Vector2 = Vector2(1, 1)  # Scale for the sprite
@export var highlight_color: Color = Color(1.2, 1.2, 1.2)  # Color when highlighted
@export var highlight_scale: float = 1.1  # How much to grow when highlighted
@export var auto_setup: bool = true  # Whether to automatically configure on ready

# Node references
@onready var _sprite = $Sprite2D
@onready var _animation_player = $AnimationPlayer
@onready var _collision_shape = $CollisionShape2D
@onready var _particle_effect = $GatherParticles

# Private variables
var _is_highlighted: bool = false
var _is_gathering: bool = false
var _is_clickable: bool = true

# Lifecycle methods
func _ready():
	# Connect input events
	input_event.connect(_on_input_event)
	
	# Auto setup if enabled
	if auto_setup and resource_id != "":
		setup_resource(resource_id)

# Public methods
func setup_resource(p_resource_id: String):
	"""Configures the node for the specified resource type"""
	resource_id = p_resource_id
	
	# Generate a unique ID if not provided
	if node_id == "":
		node_id = resource_id + "_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())
	
	# Set up the resource visuals
	_setup_visuals()
	
	# Configure collision based on resource type
	_setup_collision()
	
	# Set up particles
	_setup_particles()
	
	return self

func gather() -> bool:
	"""Initiates the gathering animation and process"""
	if _is_gathering or not _is_clickable:
		return false
	
	_is_gathering = true
	_is_clickable = false
	
	# Play gather animation if it exists
	if _animation_player and _animation_player.has_animation("gather"):
		_animation_player.play("gather")
	else:
		# Otherwise just emit particles and disappear
		if _particle_effect:
			_particle_effect.emitting = true
		
		# Wait a moment for particles
		await get_tree().create_timer(0.5).timeout
		
		# Complete gathering
		_complete_gathering()
	
	return true

func get_node_id() -> String:
	"""Returns the unique ID of this node"""
	return node_id

func highlight():
	"""Highlights the resource to indicate it can be gathered"""
	if _is_highlighted or _is_gathering:
		return
	
	_is_highlighted = true
	
	# Apply visual highlight
	if _sprite:
		_sprite.modulate = highlight_color
		_sprite.scale = sprite_scale * highlight_scale
	
	if _animation_player and _animation_player.has_animation("highlight"):
		_animation_player.play("highlight")

func unhighlight():
	"""Removes the highlight effect"""
	if not _is_highlighted or _is_gathering:
		return
	
	_is_highlighted = false
	
	# Remove visual highlight
	if _sprite:
		_sprite.modulate = Color(1, 1, 1)
		_sprite.scale = sprite_scale
	
	if _animation_player and _animation_player.has_animation("unhighlight"):
		_animation_player.play("unhighlight")

func set_clickable(clickable: bool):
	"""Sets whether this node can be clicked"""
	_is_clickable = clickable

# Private methods
func _setup_visuals():
	"""Sets up the visual appearance based on resource type"""
	if not _sprite:
		return
	
	# Try to load the resource texture if not provided
	if resource_texture == null:
		var texture_path = _get_resource_texture_path()
		if texture_path:
			resource_texture = load(texture_path)
	
	# Set the texture if we have one
	if resource_texture:
		_sprite.texture = resource_texture
	
	# Apply scale
	_sprite.scale = sprite_scale

func _setup_collision():
	"""Sets up the collision shape based on resource type"""
	if not _collision_shape:
		return
	
	# Adjust collision based on resource size
	# This could be customized more based on resource types
	var size_multiplier = 1.0
	
	match resource_id:
		"ing_lavender", "ing_mint", "ing_sage":
			# Small plants
			size_multiplier = 0.8
		"ing_mushrooms", "ing_chamomile":
			# Medium plants
			size_multiplier = 1.0
		"ing_quartz_dust", "ing_iron_filings", "ing_clay", "ing_salt", "ing_sulfur":
			# Minerals
			size_multiplier = 0.9
		"ing_moonstone", "ing_rainbow_essence":
			# Special items
			size_multiplier = 1.2
	
	# If we have a CircleShape2D, adjust the radius
	if _collision_shape.shape is CircleShape2D:
		_collision_shape.shape.radius *= size_multiplier
	# If we have a RectangleShape2D, adjust the extents
	elif _collision_shape.shape is RectangleShape2D:
		_collision_shape.shape.size *= size_multiplier  # Changed from extents to size in Godot 4

func _setup_particles():
	"""Sets up particle effects based on resource type"""
	if not _particle_effect:
		return
	
	# Configure particle color based on resource type
	var particle_color = Color(1, 1, 1)  # Default white
	
	match resource_id:
		"ing_lavender":
			particle_color = Color(0.7, 0.5, 1.0)  # Purple
		"ing_mint":
			particle_color = Color(0.5, 1.0, 0.5)  # Light green
		"ing_sage":
			particle_color = Color(0.6, 0.7, 0.5)  # Sage green
		"ing_mushrooms":
			particle_color = Color(0.8, 0.7, 0.6)  # Brown
		"ing_chamomile":
			particle_color = Color(1.0, 1.0, 0.7)  # Pale yellow
		# Minerals
		"ing_quartz_dust":
			particle_color = Color(0.9, 0.9, 0.9)  # White
		"ing_iron_filings":
			particle_color = Color(0.6, 0.6, 0.6)  # Gray
		"ing_clay":
			particle_color = Color(0.8, 0.6, 0.4)  # Brown
		"ing_salt":
			particle_color = Color(1.0, 1.0, 1.0)  # White
		"ing_sulfur":
			particle_color = Color(1.0, 0.9, 0.2)  # Yellow
		# Special
		"ing_moonstone":
			particle_color = Color(0.8, 0.8, 1.0)  # Pale blue
		"ing_rainbow_essence":
			# Rainbow particles would need custom implementation
			particle_color = Color(1.0, 0.5, 0.7)  # Pink
	
	# Set particle color - method depends on your particle system in Godot 4
	# For GPUParticles2D
	if _particle_effect is GPUParticles2D:
		# Create a gradient for the color ramp
		var gradient = Gradient.new()
		gradient.add_point(0.0, particle_color)
		gradient.add_point(1.0, Color(particle_color.r, particle_color.g, particle_color.b, 0.0))
		
		# Create a color ramp
		var color_ramp = GradientTexture1D.new()
		color_ramp.gradient = gradient
		
		# Assuming your particle material is a ParticleProcessMaterial
		var material = _particle_effect.process_material
		if material is ParticleProcessMaterial:
			material.color_ramp = color_ramp
	# For CPUParticles2D
	elif _particle_effect is CPUParticles2D:
		_particle_effect.color = particle_color
		_particle_effect.color_ramp = GradientTexture1D.new()
		_particle_effect.color_ramp.gradient = Gradient.new()
		_particle_effect.color_ramp.gradient.add_point(0.0, particle_color)
		_particle_effect.color_ramp.gradient.add_point(1.0, Color(particle_color.r, particle_color.g, particle_color.b, 0.0))
	
	# Ensure particles are not emitting by default
	_particle_effect.emitting = false

func _get_resource_texture_path() -> String:
	"""Gets the texture path for the resource"""
	if resource_id.is_empty():
		return ""
	
	# Extract category from ID
	var category = "common_plants"  # Default category
	
	if resource_id.begins_with("ing_"):
		var id_without_prefix = resource_id.substr(4)  # Remove "ing_" prefix
		
		# Determine category
		if id_without_prefix in ["lavender", "mint", "sage", "mushrooms", "chamomile"]:
			category = "common_plants"
		elif id_without_prefix in ["quartz_dust", "iron_filings", "clay", "salt", "sulfur"]:
			category = "mineral_elements" 
		elif id_without_prefix in ["beeswax", "spider_silk", "bat_wing", "snail_slime", "firefly_light"]:
			category = "animal_products"
		elif id_without_prefix in ["morning_dew", "moonstone", "fire_ash", "pure_water", "rainbow_essence"]:
			category = "special_elements"
	
	# Return the path
	return "res://assets/images/ingredients/%s/%s.png" % [category, resource_id]

func _on_input_event(_viewport, event, _shape_idx):
	"""Handles input events on this node"""
	if not _is_clickable or _is_gathering:
		return
	
	# Check for mouse/touch interactions
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		resource_clicked.emit(node_id)
		gather()
	# For highlight on hover, could add InputEventMouseMotion handling here

func _on_animation_finished(anim_name):
	"""Called when an animation completes"""
	if anim_name == "gather":
		_complete_gathering()

func _complete_gathering():
	"""Completes the gathering process and emits the signal"""
	resource_gathered.emit(node_id)
	
	# Queue this node for deletion
	queue_free()
