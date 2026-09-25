extends Area3D
class_name TicketSystem

@onready var camera_position: Marker3D = $"Cabinet Camera Position"
@onready var table_camera_position: Marker3D = $"Table Camera Position"
@onready var table_collision: CollisionShape3D = $"Table Collision"
var interaction_collision_layer: int

func _ready() -> void:
	interaction_collision_layer = collision_layer


func get_interaction_prompt(actor: Node, shape_index: int = -1, hit_position := Vector3.ZERO) -> String:
	if _is_table_hit(shape_index, hit_position):
		return "Left click to use ticket table"
	if actor.has_method("is_camera_fixed") and actor.is_camera_fixed():
		if actor.held_item is Ticket:
			return "Left click to return ticket"
		return ""
	return "Left click to inspect ticket system"

func activate(actor: Node, shape_index: int = -1, hit_position := Vector3.ZERO) -> bool:
	if _is_table_hit(shape_index, hit_position):
		if actor.has_method("set_inspection_camera"):
			actor.set_inspection_camera(table_camera_position.global_transform, "ticket_table")
		return true

	if actor.has_method("is_camera_fixed") and actor.is_camera_fixed():
		if not actor.held_item is Ticket:
			return false
		var ticket: Ticket = actor.held_item
		ticket.consume()
		actor.held_item = null
		return true

	if not actor.has_method("set_camera_transform"):
		return false
	actor.set_inspection_camera(camera_position.global_transform, "ticket_system")
	collision_layer = interaction_collision_layer
	return true

func _is_table_hit(shape_index: int, hit_position: Vector3) -> bool:
	if table_collision == null:
		return false
	if shape_index >= 0:
		var owner_id := shape_find_owner(shape_index)
		if owner_id != -1 and shape_owner_get_owner(owner_id) == table_collision:
			return true
	if hit_position == Vector3.ZERO or not table_collision.shape is BoxShape3D:
		return false
	var local_hit := table_collision.global_transform.affine_inverse() * hit_position
	var half_size := (table_collision.shape as BoxShape3D).size / 2.0
	return abs(local_hit.x) <= half_size.x and abs(local_hit.y) <= half_size.y and abs(local_hit.z) <= half_size.z

func deactivate() -> void:
	collision_layer = interaction_collision_layer
	var ticket_stack_rack := get_node_or_null("TIcket Cabinet") as TicketStackRack
	if ticket_stack_rack:
		ticket_stack_rack.clear_selection()
