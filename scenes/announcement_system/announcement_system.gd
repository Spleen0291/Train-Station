extends Area3D
class_name AnnouncementSystem

@onready var camera_position: Marker3D = $"Camera Position"
var interaction_collision_layer: int

func _ready() -> void:
	interaction_collision_layer = collision_layer

func get_interaction_prompt(_actor: Node) -> String:
	return "Left click to inspect announcement system"

func activate(actor: Node) -> bool:
	if not actor.has_method("set_camera_transform"):
		return false
	actor.set_inspection_camera(camera_position.global_transform, "announcement")
	collision_layer = 0
	return true

func deactivate() -> void:
	collision_layer = interaction_collision_layer
