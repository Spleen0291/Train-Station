extends Node3D
class_name CassetteRecorder

const INTERACTION_LAYER := 4
@export var BUTTON_SEEK_START_INTERVAL := 0.4
@export var BUTTON_SEEK_MIN_INTERVAL := 0.04
@export var BUTTON_SEEK_ACCELERATION_TIME := 3.0

signal cassette_removed(cassette: Node3D)
signal slots_updated(source_phrase: String, blank_phrase: String, source_preview_index: int, blank_preview_index: int)

@onready var holder: Node3D = $Holder
@onready var flap: Node3D = $Flap
@onready var holder_mesh: MeshInstance3D = $Holder/MeshInstance3D
@onready var holder_position: Node3D = $Eject/HolderPosition
@onready var flap_position: Marker3D = $Eject/FlapEjectedPosition
@onready var content_label: Label3D = $ContentLabel

var source_slot: Node3D
var blank_slot: Node3D
var held_cassette: Node3D = null
var holder_home_transform: Transform3D
var flap_home_transform: Transform3D
var cassette_ejected := false
var cassette_seated := false
var pointer_timer: Timer
var source_index := 0
var blank_index := 0
var source_cassette: Node3D = null
var recording_player: CassettePlayer = null
var is_copying := false
var is_erasing := false
var button_seek_direction := 0
var button_seek_elapsed := 0.0
var button_seek_interval := 0.0

func set_content_display(text: String) -> void:
	content_label.text = text
	_update_content_visibility()

func _update_content_visibility() -> void:
	content_label.visible = content_label.text != "" and cassette_seated

func _ready() -> void:
	if holder:
		holder_home_transform = holder.global_transform
	if flap:
		flap_home_transform = flap.global_transform
		source_slot = holder
		blank_slot = holder
		flap.collision_layer = 0
	pointer_timer = Timer.new()
	pointer_timer.one_shot = false
	add_child(pointer_timer)
	pointer_timer.timeout.connect(_on_pointer_timeout)

func _emit_slots_updated() -> void:
	var source_phrase := ""
	var blank_phrase := ""
	if source_cassette:
		source_phrase = source_cassette.phrase
	if held_cassette:
		blank_phrase = held_cassette.phrase
	emit_signal("slots_updated", source_phrase, blank_phrase, source_index, blank_index)

func get_interaction_prompt(_actor: Node) -> String:
	return "Left click to inspect cassette recorder"

func activate(actor: Node) -> bool:
	if not actor.has_method("set_camera_transform"):
		return false
	return true

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
	if holder:
		holder.global_transform = holder_position.global_transform
	if flap:
		flap.global_transform = flap_position.global_transform
		flap.collision_layer = INTERACTION_LAYER
	if held_cassette:
		held_cassette.global_transform = holder_position.global_transform
		if holder:
			holder.collision_layer = 0 if held_cassette else INTERACTION_LAYER
	cassette_seated = false
	cassette_ejected = true
	_update_content_visibility()

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
	if holder_mesh:
		holder_mesh.visible = false
	if holder:
		holder.collision_layer = 0
	if flap:
		flap.collision_layer = INTERACTION_LAYER
	held_cassette = cassette
	cassette_seated = false
	_emit_slots_updated()
	return true

func take(hold_position: Node3D, keep_holder_ejected := false) -> Node3D:
	if not held_cassette:
		return null
	var c = held_cassette
	held_cassette = null
	c.attach_to(hold_position)
	c.collision_layer = 0
	if not keep_holder_ejected and holder:
		holder.global_transform = holder_home_transform
	if holder_mesh:
		holder_mesh.visible = true
	if holder:
		holder.collision_layer = INTERACTION_LAYER
	if flap:
		flap.collision_layer = INTERACTION_LAYER
	cassette_seated = false
	cassette_ejected = keep_holder_ejected
	_update_content_visibility()
	_emit_slots_updated()
	return c

func seat_cassette() -> bool:
	if not held_cassette or cassette_seated or not cassette_ejected:
		return false
	if holder:
		holder.global_transform = holder_home_transform
	if flap:
		flap.global_transform = flap_home_transform
	if holder_mesh:
		holder_mesh.visible = false
	if holder:
		holder.collision_layer = 0
	if flap:
		flap.collision_layer = 0
	cassette_seated = true
	cassette_ejected = false
	_update_content_visibility()
	return true

func close_flap() -> bool:
	if not cassette_ejected or held_cassette:
		return false
	if holder:
		holder.global_transform = holder_home_transform
	if flap:
		flap.global_transform = flap_home_transform
	if holder_mesh:
		holder_mesh.visible = true
	if holder:
		holder.collision_layer = INTERACTION_LAYER
	if flap:
		flap.collision_layer = 0
	cassette_ejected = false
	_update_content_visibility()
	return true

func start_copying_from_player(player: CassettePlayer, source_start_index := -1) -> bool:
	if player == null or player.held_cassette == null or held_cassette == null:
		return false
	source_cassette = player.held_cassette
	if source_start_index >= 0:
		source_index = source_start_index
	else:
		source_index = 0
	source_index = clamp(source_index, 0, source_cassette.phrase.length())
	blank_index = clamp(blank_index, 0, held_cassette.phrase.length())
	if source_index >= source_cassette.phrase.length():
		_emit_slots_updated()
		return false
	return true

func _find_recording_player() -> CassettePlayer:
	for player in get_tree().get_nodes_in_group("CassettePlayer"):
		if player is CassettePlayer and player.is_recording and player.cassette_seated:
			return player
	return null

func run_copy(actor: Node = null) -> bool:
	if held_cassette == null:
		return false
	if is_copying:
		stop_copying()
		return true
	if is_erasing:
		return false
	var player := _find_recording_player()
	if player == null:
		for candidate in get_tree().get_nodes_in_group("CassettePlayer"):
			if candidate is CassettePlayer and candidate.cassette_seated:
				if actor and actor.has_method("stop_cassette_transport"):
					actor.stop_cassette_transport()
				candidate.record_button(self)
				player = candidate if candidate.is_recording else null
				break
		if player == null:
			return false
	recording_player = player
	var source_start_index := -1
	if actor and actor.get("pointer_index") != null:
		source_start_index = int(actor.get("pointer_index"))
	if not start_copying_from_player(player, source_start_index):
		return false
	if source_index >= source_cassette.phrase.length():
		_emit_slots_updated()
		return false
	pointer_timer.wait_time = 0.15
	pointer_timer.start()
	is_copying = true
	return true

func stop_copying() -> void:
	_stop_pointer_action()
	if recording_player and recording_player.is_recording:
		recording_player.stop_recording()
	recording_player = null
	source_cassette = null
	source_index = 0

func erase_blank() -> bool:
	if held_cassette == null:
		return false
	if is_copying:
		_stop_pointer_action()
	if is_erasing:
		_stop_pointer_action()
		return true
	blank_index = clamp(blank_index, 0, held_cassette.phrase.length())
	if blank_index >= held_cassette.phrase.length():
		_emit_slots_updated()
		return false
	pointer_timer.wait_time = 0.2
	pointer_timer.start()
	is_erasing = true
	return true

func _stop_pointer_action() -> void:
	if pointer_timer and not pointer_timer.is_stopped():
		pointer_timer.stop()
	button_seek_direction = 0
	button_seek_elapsed = 0.0
	is_copying = false
	is_erasing = false

func _on_pointer_timeout() -> void:
	if button_seek_direction != 0:
		if button_seek_direction < 0:
			_seek_left_from_button()
		else:
			_seek_right_from_button()
		button_seek_elapsed += button_seek_interval
		button_seek_interval = _get_button_seek_interval()
		pointer_timer.start(button_seek_interval)
		return
	if is_erasing:
		_erase_next_character()
		return
	if source_cassette == null or held_cassette == null:
		_stop_pointer_action()
		return
	if source_index >= source_cassette.phrase.length():
		_stop_pointer_action()
		_emit_slots_updated()
		return
	var ch : String = source_cassette.phrase.substr(source_index, 1)
	var b: String = held_cassette.phrase
	if blank_index < b.length():
		held_cassette.phrase = b.substr(0, blank_index) + ch + b.substr(blank_index + 1)
	else:
		held_cassette.phrase = b + ch
	source_index += 1
	blank_index += 1
	_emit_slots_updated()

func _erase_next_character() -> void:
	if held_cassette == null:
		_stop_pointer_action()
		return
	if blank_index >= held_cassette.phrase.length():
		_stop_pointer_action()
		_emit_slots_updated()
		return
	var b: String = held_cassette.phrase
	held_cassette.phrase = b.substr(0, blank_index) + " " + b.substr(blank_index + 1)
	blank_index += 1
	_emit_slots_updated()

func rewind_button(_actor: Node) -> bool:
	if held_cassette == null:
		return false
	if button_seek_direction == -1:
		release_button_seek()
		return true
	_stop_pointer_action()
	_seek_left_from_button()
	button_seek_direction = -1
	_start_button_seek_timer()
	return true

func forward_button(_actor: Node) -> bool:
	if held_cassette == null:
		return false
	if button_seek_direction == 1:
		release_button_seek()
		return true
	_stop_pointer_action()
	_seek_right_from_button()
	button_seek_direction = 1
	_start_button_seek_timer()
	return true

func release_button_seek() -> void:
	if button_seek_direction != 0:
		_stop_pointer_action()

func _start_button_seek_timer() -> void:
	button_seek_elapsed = 0.0
	button_seek_interval = BUTTON_SEEK_START_INTERVAL
	pointer_timer.wait_time = button_seek_interval
	pointer_timer.start()

func _get_button_seek_interval() -> float:
	var progress := clampf(button_seek_elapsed / BUTTON_SEEK_ACCELERATION_TIME, 0.0, 1.0)
	return lerpf(BUTTON_SEEK_START_INTERVAL, BUTTON_SEEK_MIN_INTERVAL, progress)

func _seek_left_from_button() -> void:
	if is_copying and source_cassette != null:
		source_index = max(source_index - 1, 0)
	else:
		blank_index = max(blank_index - 1, 0)
	_emit_slots_updated()

func _seek_right_from_button() -> void:
	if is_copying and source_cassette != null:
		source_index = min(source_index + 1, source_cassette.phrase.length())
	else:
		blank_index = min(blank_index + 1, held_cassette.phrase.length())
	_emit_slots_updated()

func seek_left() -> void:
	if source_cassette == null:
		return
	source_index = max(source_index - 1, 0)
	_emit_slots_updated()

func seek_right() -> void:
	if source_cassette == null:
		return
	source_index = min(source_index + 1, source_cassette.phrase.length())
	_emit_slots_updated()

func seek_blank_left() -> void:
	if held_cassette == null:
		return
	blank_index = max(blank_index - 1, 0)
	_emit_slots_updated()

func seek_blank_right() -> void:
	if held_cassette == null:
		return
	blank_index = min(blank_index + 1, held_cassette.phrase.length())
	_emit_slots_updated()

func reset_blank() -> void:
	if held_cassette == null:
		return
	held_cassette.phrase = ""
	blank_index = 0
	_emit_slots_updated()
