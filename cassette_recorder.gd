extends Node3D

@onready var source_slot: Node3D = $SourceSlot
@onready var blank_slot: Node3D = $BlankSlot

signal slots_updated(source_phrase: String, blank_phrase: String, source_preview_index: int, blank_preview_index: int)

var pointer_timer: Timer
var pointer_text: String = ""
var pointer_index: int = 0
var is_copying: bool = false
var is_erasing: bool = false
var current_source: Node = null
var source_copied_count: int = 0
var preview_index: int = 0
var blank_preview_index: int = 0
var prev_blank_cassette: Node = null
var prev_source_cassette: Node = null

func _ready() -> void:
	_emit_slots_updated()
	pointer_timer = Timer.new()
	pointer_timer.one_shot = false
	add_child(pointer_timer)
	pointer_timer.timeout.connect(_on_pointer_timeout)

func _emit_slots_updated() -> void:
	var source_cassette = source_slot.held_cassette
	var blank_cassette = blank_slot.held_cassette
	var source_phrase := ""
	var blank_phrase := ""
	if source_cassette:
		source_phrase = source_cassette.phrase
	if blank_cassette:
		blank_phrase = blank_cassette.phrase
	emit_signal("slots_updated", source_phrase, blank_phrase, preview_index, blank_preview_index)
 	
func on_slot_changed() -> void:
	# If a new cassette was inserted into the source slot, move source preview to start
	var s = source_slot.held_cassette
	if s != prev_source_cassette:
		prev_source_cassette = s
		if s != null:
			preview_index = 0

	# If a new cassette was inserted into the blank slot, move blank pointer to its end
	var b = blank_slot.held_cassette
	if b != prev_blank_cassette:
		# blank changed (inserted or removed)
		prev_blank_cassette = b
		if b != null:
			blank_preview_index = b.phrase.length()
	_emit_slots_updated()

func run_copy() -> void:
	var source_cassette = source_slot.held_cassette
	var blank_cassette = blank_slot.held_cassette

	if source_cassette == null or blank_cassette == null:
		return

	if is_erasing:
		_stop_pointer_action()

	# Toggle copying
	if is_copying:
		_stop_pointer_action()
		return

	# start copying: prepare source text and resume/initialize per-source progress
	pointer_text = source_cassette.phrase
	if current_source != source_cassette:
		current_source = source_cassette
		source_copied_count = 0
		# keep source preview as-is for user-controlled pointer, but clamp
		preview_index = clamp(preview_index, 0, pointer_text.length())
	# start copying from where the source preview pointer currently is
	pointer_index = clamp(preview_index, 0, pointer_text.length())
	source_copied_count = pointer_index
	# ensure blank preview index is valid for current blank cassette
	if blank_cassette:
		blank_preview_index = clamp(blank_preview_index, 0, blank_cassette.phrase.length())
	# if we've already copied entire source (pointer at end), nothing to do
	if pointer_index >= pointer_text.length():
		_emit_slots_updated()
		return

	# start timer
	pointer_timer.wait_time = 0.15
	pointer_timer.start()
	is_copying = true

func erase_blank() -> void:
	var blank_cassette = blank_slot.held_cassette
	if blank_cassette == null:
		return

	if is_copying:
		_stop_pointer_action()

	if is_erasing:
		_stop_pointer_action()
		return

	blank_preview_index = clamp(blank_preview_index, 0, blank_cassette.phrase.length())
	if blank_preview_index >= blank_cassette.phrase.length():
		_emit_slots_updated()
		return

	pointer_timer.wait_time = 0.2
	pointer_timer.start()
	is_erasing = true

func _stop_pointer_action() -> void:
	if pointer_timer and not pointer_timer.is_stopped():
		pointer_timer.stop()
	is_copying = false
	is_erasing = false

func _on_pointer_timeout() -> void:
	if is_erasing:
		_erase_next_character()
		return

	var source_cassette = source_slot.held_cassette
	var blank_cassette = blank_slot.held_cassette
	if source_cassette == null or blank_cassette == null:
		if pointer_timer and not pointer_timer.is_stopped():
			pointer_timer.stop()
		is_copying = false
		return

	if pointer_index >= pointer_text.length():
		# finished copying
		if pointer_timer and not pointer_timer.is_stopped():
			pointer_timer.stop()
		is_copying = false
		# mark source as fully copied
		source_copied_count = pointer_index
		current_source = null
		_emit_slots_updated()
		return

	# overwrite the character at the blank pointer; append only at the end
	var ch := pointer_text.substr(pointer_index, 1)
	var b : String = blank_cassette.phrase
	if blank_preview_index < b.length():
		blank_cassette.phrase = b.substr(0, blank_preview_index) + ch + b.substr(blank_preview_index + 1)
	else:
		blank_cassette.phrase = b + ch
	pointer_index += 1
	# advance both previews: source preview follows pointer, blank preview moves past inserted char
	preview_index = pointer_index
	blank_preview_index += 1
	source_copied_count = pointer_index
	# notify UI each character
	_emit_slots_updated()

func _erase_next_character() -> void:
	var blank_cassette = blank_slot.held_cassette
	if blank_cassette == null:
		_stop_pointer_action()
		return

	if blank_preview_index >= blank_cassette.phrase.length():
		_stop_pointer_action()
		_emit_slots_updated()
		return

	var b: String = blank_cassette.phrase
	blank_cassette.phrase = b.substr(0, blank_preview_index) + " " + b.substr(blank_preview_index + 1)
	blank_preview_index += 1
	_emit_slots_updated()

func seek_left() -> void:
	if source_slot.held_cassette == null:
		return
	preview_index = max(preview_index - 1, 0)
	_emit_slots_updated()

func seek_right() -> void:
	var src = source_slot.held_cassette
	if src == null:
		return
	preview_index = min(preview_index + 1, src.phrase.length())
	_emit_slots_updated()

func seek_blank_left() -> void:
	var b = blank_slot.held_cassette
	if b == null:
		return
	blank_preview_index = max(blank_preview_index - 1, 0)
	_emit_slots_updated()

func seek_blank_right() -> void:
	var b2 = blank_slot.held_cassette
	if b2 == null:
		return
	blank_preview_index = min(blank_preview_index + 1, b2.phrase.length())
	_emit_slots_updated()

func reset_blank() -> void:
	var b = blank_slot.held_cassette
	if b == null:
		return
	b.phrase = ""
	blank_preview_index = 0
	_emit_slots_updated()
