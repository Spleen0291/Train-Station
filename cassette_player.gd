extends StaticBody3D
class_name CassettePlayer

signal cassette_inserted(phrase: String)

@onready var attach_point: Node3D = $AttachPoint

var held_cassette: Node3D = null

func insert(cassette: Node3D) -> bool:
	# refuse if player already has an attached cassette
	if held_cassette:
		return false
	cassette.attach_to(attach_point)
	held_cassette = cassette
	# Emit the phrase immediately so the announcement displays on insert
	var phrase: String = held_cassette.phrase
	cassette_inserted.emit(phrase)
	return true

func play() -> void:
	# Play (prototype: emit the assembled text) only when explicitly requested
	if not held_cassette:
		return
	var phrase: String = held_cassette.phrase
	cassette_inserted.emit(phrase)

func take(hold_position: Node3D) -> Node3D:
	if not held_cassette:
		return null
	var c = held_cassette
	held_cassette = null
	c.attach_to(hold_position)
	return c
