extends Node
## Helper class for safely interacting with gathering system

# This class provides a safe way to interact with the gathering system
# without storing direct references to it

# Static methods for gathering operations
class_name GatheringHelper

static func initialize_gathering_area(area_id: String, spawn_positions: Array, initial_resources: Array = []):
    """Safely initializes a gathering area"""
    var gathering_system = _get_gathering_system()
    if gathering_system and gathering_system.has_method("initialize_gathering_area"):
        return gathering_system.initialize_gathering_area(area_id, spawn_positions, initial_resources)
    return false

static func gather_resource(node_id: String):
    """Safely gathers a resource"""
    var gathering_system = _get_gathering_system()
    if gathering_system and gathering_system.has_method("gather_resource"):
        return gathering_system.gather_resource(node_id)
    return {"success": false, "error": "Gathering system not available"}

static func spawn_resource_at_position(resource_id: String, area_id: String, position: Vector2):
    """Safely spawns a resource at a specific position"""
    var gathering_system = _get_gathering_system()
    if gathering_system and gathering_system.has_method("spawn_resource_at_position"):
        return gathering_system.spawn_resource_at_position(resource_id, area_id, position)
    return null

static func refresh_daily_resources():
    """Safely refreshes all resources for a new day"""
    var gathering_system = _get_gathering_system()
    if gathering_system and gathering_system.has_method("refresh_daily_resources"):
        return gathering_system.refresh_daily_resources()
    return false

static func update_resources():
    """Safely updates resource states"""
    var gathering_system = _get_gathering_system()
    if gathering_system and gathering_system.has_method("update_resources"):
        return gathering_system.update_resources()
    return false

# Helper to safely get gathering system reference
static func _get_gathering_system():
    return Engine.get_main_loop().get_root().get_node_or_null("/root/GatheringSystem")