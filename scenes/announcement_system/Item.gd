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

func get_interaction_prompt(actor: Node) -> String:
	var cassette_player := _get_cassette_player()
	if cassette_player and cassette_player.held_cassette == self and cassette_player.cassette_ejected and not cassette_player.cassette_seated and not actor.held_item:
		return "Left click to take cassette"
	var cassette_recorder := _get_cassette_recorder()
	if cassette_recorder and cassette_recorder.held_cassette == self and cassette_recorder.cassette_ejected and not cassette_recorder.cassette_seated and not actor.held_item:
		return "Left click to take cassette"
	return ""

func activate(actor: Node) -> bool:
	if actor.held_item:
		if actor.held_item == self:
			return false
		actor.held_item.drop()
		actor.held_item = null
	var cassette_player := _get_cassette_player()
	var cassette_recorder := _get_cassette_recorder()
	var cassette: Node3D
	if cassette_player and cassette_player.held_cassette == self and cassette_player.cassette_ejected:
		cassette = cassette_player.take(actor.hold_position, true)
		if cassette == null:
			return false
		actor.held_item = cassette
		cassette_player.cassette_removed.emit(cassette)
		return true
	if cassette_recorder == null or cassette_recorder.held_cassette != self or not cassette_recorder.cassette_ejected:
		pickup(actor.hold_position)
		actor.held_item = self
		return true
	cassette = cassette_recorder.take(actor.hold_position, true)
	if cassette == null:
		return false
	actor.held_item = cassette
	cassette_recorder.cassette_removed.emit(cassette)
	return true

func _get_cassette_player() -> CassettePlayer:
	var node := get_parent()
	while node:
		if node is CassettePlayer:
			return node
		node = node.get_parent()
	return null

func _get_cassette_recorder() -> CassetteRecorder:
	var node := get_parent()
	while node:
		if node is CassetteRecorder:
			return node
		node = node.get_parent()
	return null
