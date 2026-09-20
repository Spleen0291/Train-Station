extends Node3D
class_name CassettePlayer

const INTERACTION_LAYER := 4

signal cassette_inserted(phrase: String)
signal cassette_removed(cassette: Node3D)
signal recording_mode_changed(active: bool)

@onready var holder: Node3D = $Holder
@onready var flap: Node3D = $Flap
@onready var holder_mesh: MeshInstance3D = $Holder/MeshInstance3D
@onready var holder_position: Node3D = $Eject/HolderPosition
@onready var flap_position: Marker3D = $Eject/FlapEjectedPosition
@onready var content_label: Label3D = $ContentLabel

var held_cassette: Node3D = null
var holder_home_transform: Transform3D
var flap_home_transform: Transform3D
var cassette_ejected := false
var cassette_seated := false
var is_recording := false

func set_content_display(text: String) -> void:
	content_label.text = text
	content_label.visible = text != ""

func _ready() -> void:
	holder_home_transform = holder.global_transform
	flap_home_transform = flap.global_transform
	flap.collision_layer = 0

func eject(hold_position: Node3D = null) -> Node3D:
	if held_cassette:
		if cassette_seated and hold_position:
			_move_to_ejected_position()
			return take(hold_position, true)
		if cassette_seated:
			_move_to_ejected_position()
		return null
	if cassette_ejected:
		return null
	_move_to_ejected_position()
	if held_cassette and hold_position:
		return take(hold_position)
	return null

func _move_to_ejected_position() -> void:
	holder.global_transform = holder_position.global_transform
	flap.global_transform = flap_position.global_transform
	flap.collision_layer = INTERACTION_LAYER
	if held_cassette:
		held_cassette.global_transform = holder_position.global_transform
		holder.collision_layer = 0 if held_cassette else INTERACTION_LAYER
	cassette_seated = false
	cassette_ejected = true

func play_button(actor: Node) -> bool:
	if not cassette_seated or not actor.has_method("play_cassette_button"):
		return false
	_stop_recorder_copying()
	if is_recording:
		stop_recording()
	actor.stop_cassette_button(self)
	actor.play_cassette_button(self)
	return true

func _stop_recorder_copying() -> void:
	for recorder in get_tree().get_nodes_in_group("CassetteCopier"):
		if recorder != self and recorder.has_method("stop_copying") and recorder.get("is_copying"):
			recorder.stop_copying()

func record_button(actor: Node) -> bool:
	if not cassette_seated:
		return false
	if is_recording:
		stop_recording()
		return true
	if actor.has_method("stop_cassette_button"):
		actor.stop_cassette_button(self)
	is_recording = true
	recording_mode_changed.emit(true)
	return true

func rewind_button(actor: Node) -> bool:
	if not cassette_seated or not actor.has_method("rewind_cassette_button"):
		return false
	_stop_recorder_copying()
	actor.stop_cassette_button(self)
	actor.rewind_cassette_button(self)
	return true

func forward_button(actor: Node) -> bool:
	if not cassette_seated or not actor.has_method("forward_cassette_button"):
		return false
	_stop_recorder_copying()
	actor.stop_cassette_button(self)
	actor.forward_cassette_button(self)
	return true

func stop_button(actor: Node) -> bool:
	if is_recording:
		stop_recording()
		return true
	if not cassette_seated or not actor.has_method("stop_cassette_button"):
		return false
	actor.stop_cassette_button(self)
	return true

func stop_recording() -> void:
	if not is_recording:
		return
	is_recording = false
	recording_mode_changed.emit(false)

func insert_from_actor(actor: Node) -> bool:
	if not actor.held_item:
		return false
	if insert(actor.held_item):
		actor.held_item = null
		return true
	return false

func insert(cassette: Node3D) -> bool:
	if held_cassette or not cassette_ejected:
		return false
	cassette.attach_to(holder)
	cassette.collision_layer = INTERACTION_LAYER
	holder_mesh.visible = false
	holder.collision_layer = 0
	flap.collision_layer = INTERACTION_LAYER
	held_cassette = cassette
	cassette_seated = false
	return true

func play() -> void:
	if not held_cassette or not cassette_seated:
		return
	var phrase: String = held_cassette.phrase
	cassette_inserted.emit(phrase)

func take(hold_position: Node3D, keep_holder_ejected := false) -> Node3D:
	if not held_cassette:
		return null
	var c = held_cassette
	held_cassette = null
	c.attach_to(hold_position)
	c.collision_layer = 0
	if not keep_holder_ejected:
		holder.global_transform = holder_home_transform
	holder_mesh.visible = true
	holder.collision_layer = INTERACTION_LAYER
	flap.collision_layer = INTERACTION_LAYER
	cassette_seated = false
	cassette_ejected = keep_holder_ejected
	return c

func seat_cassette() -> bool:
	if not held_cassette or cassette_seated or not cassette_ejected:
		return false
	holder.global_transform = holder_home_transform
	flap.global_transform = flap_home_transform
	holder_mesh.visible = false
	holder.collision_layer = 0
	flap.collision_layer = 0
	cassette_seated = true
	cassette_ejected = false
	var phrase: String = held_cassette.phrase
	cassette_inserted.emit(phrase)
	return true

func close_flap() -> bool:
	if not cassette_ejected or held_cassette:
		return false
	holder.global_transform = holder_home_transform
	flap.global_transform = flap_home_transform
	holder_mesh.visible = true
	holder.collision_layer = INTERACTION_LAYER
	flap.collision_layer = 0
	cassette_ejected = false
	return true
