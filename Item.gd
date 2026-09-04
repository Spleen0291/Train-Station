extends StaticBody3D

@export var item_name := "Cassette"
@export_multiline var phrase := ""   # empty string = a "blank" cassette

var is_held := false
var original_parent: Node3D = null
var original_transform: Transform3D

func pickup(hold_position: Node3D) -> void:
	if is_held:
		return
	is_held = true

	original_parent = get_parent()
	original_transform = global_transform

	remove_from_group("Pickupable")
	collision_layer = 0
	collision_mask = 0

	attach_to(hold_position)

func drop() -> void:
	if not is_held:
		return
	is_held = false

	attach_to(original_parent)
	global_transform = original_transform

	add_to_group("Pickupable")
	collision_layer = 2
	collision_mask = 1
	

func attach_to(parent: Node3D) -> void:
	var current_parent = get_parent()
	if current_parent:
		current_parent.remove_child(self)
	parent.add_child(self)
	position = Vector3.ZERO
	rotation = Vector3.ZERO
