extends StaticBody3D
class_name CassetteRack

@onready var camera_position: Marker3D = $"Camera Position"
var interaction_collision_layer: int
var announcement_system: Area3D
var announcement_collision_layer: int

func _ready() -> void:
	interaction_collision_layer = collision_layer
	announcement_system = get_tree().get_first_node_in_group("AnnouncementSystem") as Area3D
	if announcement_system:
		announcement_collision_layer = announcement_system.collision_layer

func get_interaction_prompt(_actor: Node) -> String:
	return "Left click to inspect cassette rack"

func activate(actor: Node) -> bool:
	if not actor.has_method("set_camera_transform"):
		return false
	actor.set_inspection_camera(camera_position.global_transform, "rack")
	if announcement_system:
		announcement_system.collision_layer = 0
	return true

func deactivate() -> void:
	collision_layer = interaction_collision_layer
	if announcement_system:
		announcement_system.collision_layer = announcement_collision_layer