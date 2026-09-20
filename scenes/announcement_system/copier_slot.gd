extends StaticBody3D

@export var attach_point: Node3D

var held_cassette: Node3D = null

func get_prompt_text(player_held_item: Node3D) -> String:
	if held_cassette:
		return "Press E to take cassette"
	elif player_held_item:
		return "Press E to insert cassette"
	return ""

func interact(player_held_item: Node3D, hold_position: Node3D) -> Node3D:
	if held_cassette:
		var c = held_cassette
		held_cassette = null
		c.attach_to(hold_position)
		# notify parent recorder that slot content changed (cassette taken)
		if get_parent() and get_parent().has_method("on_slot_changed"):
			get_parent().on_slot_changed()
		return c
	elif player_held_item:
		var c = player_held_item
		held_cassette = c
		c.attach_to(attach_point)
		# notify parent recorder that slot content changed
		if get_parent() and get_parent().has_method("on_slot_changed"):
			get_parent().on_slot_changed()
		return null
	return player_held_item
