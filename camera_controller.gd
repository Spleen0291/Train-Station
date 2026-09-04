extends Camera3D

@export var CAMERA_SENS = 0.003
@export var PICKUP_RANGE = 3.0
@export var prompt_label: Label
@export var playing_label: Label
@export var assembled_label: Label
@export var keybind_panel: Control
@export var announcement_manager: AnnouncementManager
@export var hold_position: Node3D
@export var cassette_player: CassettePlayer
@export var cassette_recorder: Node
@export var playing_label_duration := 5.0
@export var POINTER_STEP_TIME := 0.15
@export var HOLD_REPEAT_INTERVAL := 0.1

var pointer_timer: Timer
var pointer_index: int = 0
var pointer_text: String = ""
var assembled_phrase_for_check: String = ""
@onready var announcement_timer: Timer = $AnnouncementTimer
var current_cassette_text: String = ""
var current_cassette_appended_count: int = 0

var current_target: Node3D = null
var held_item: Node3D = null
var current_announcement := ""
var is_playing: bool = false
var announcement_completed_correctly: bool = false
var announcement_started: bool = false
var hold_left: bool = false
var hold_right: bool = false
var left_acc: float = 0.0
var right_acc: float = 0.0
var last_train_key: String = ""

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().set_meta("player_input_locked", false)
	var game_manager = _get_game_manager()
	if game_manager:
		last_train_key = _get_train_key(game_manager)
	if cassette_player:
		cassette_player.cassette_inserted.connect(_on_cassette_inserted)
	if cassette_recorder and cassette_recorder.has_signal("slots_updated"):
		cassette_recorder.connect("slots_updated", Callable(self, "_on_recorder_slots_updated"))
	
	pointer_timer = Timer.new()
	pointer_timer.one_shot = false
	add_child(pointer_timer)
	pointer_timer.timeout.connect(_on_pointer_timeout)
	# configure announcement clear timer
	if announcement_timer:
		announcement_timer.one_shot = true
		announcement_timer.timeout.connect(_on_announcement_timer_timeout)

func _physics_process(delta: float) -> void:
	if keybind_panel and keybind_panel.visible:
		hold_left = false
		hold_right = false
		return
	_check_for_pickup()
	_check_for_new_train()

	# handle held arrow repeat for pointer movement
	if hold_left:
		left_acc += delta
		if left_acc >= HOLD_REPEAT_INTERVAL:
			# perform left action depending on focused target
			if current_target and current_target.is_in_group("CassettePlayer"):
				pointer_index = max(pointer_index - 1, 0)
				var left := pointer_text.substr(0, pointer_index)
				var right := pointer_text.substr(pointer_index)
				playing_label.text = "\"" + left + "|" + right + "\""
			elif current_target and current_target.is_in_group("CopierSlot") and cassette_recorder:
				if current_target == cassette_recorder.source_slot and cassette_recorder.has_method("seek_left"):
					cassette_recorder.seek_left()
				elif current_target == cassette_recorder.blank_slot and cassette_recorder.has_method("seek_blank_left"):
					cassette_recorder.seek_blank_left()
			left_acc = 0.0

	if hold_right:
		right_acc += delta
		if right_acc >= HOLD_REPEAT_INTERVAL:
			# perform right action depending on focused target
			if current_target and current_target.is_in_group("CassettePlayer"):
				pointer_index = min(pointer_index + 1, pointer_text.length())
				var left2 := pointer_text.substr(0, pointer_index)
				var right2 := pointer_text.substr(pointer_index)
				playing_label.text = "\"" + left2 + "|" + right2 + "\""
				if pointer_index >= pointer_text.length():
					if announcement_manager and announcement_manager.check_announcement(assembled_phrase_for_check):
						announcement_completed_correctly = true
						announcement_manager.correct_announcement.emit()
			elif current_target and current_target.is_in_group("CopierSlot") and cassette_recorder:
				if current_target == cassette_recorder.source_slot and cassette_recorder.has_method("seek_right"):
					cassette_recorder.seek_right()
				elif current_target == cassette_recorder.blank_slot and cassette_recorder.has_method("seek_blank_right"):
					cassette_recorder.seek_blank_right()
			right_acc = 0.0

func _get_game_manager() -> GameManager:
	if announcement_manager:
		return announcement_manager.game_manager
	return null

func _get_train_key(game_manager: GameManager) -> String:
	return str(game_manager.current_day) + ":" + str(game_manager.current_train_index)

func _check_for_new_train() -> void:
	var game_manager = _get_game_manager()
	if game_manager == null:
		return

	var train_key := _get_train_key(game_manager)
	if last_train_key == "":
		last_train_key = train_key
		return
	if train_key == last_train_key:
		return

	last_train_key = train_key
	announcement_completed_correctly = false
	announcement_started = false
	assembled_phrase_for_check = ""
	current_announcement = ""
	current_cassette_appended_count = 0
	if announcement_timer and not announcement_timer.is_stopped():
		announcement_timer.stop()
	if pointer_timer and not pointer_timer.is_stopped():
		pointer_timer.stop()
	is_playing = false
	if assembled_label:
		assembled_label.text = ""
		assembled_label.visible = false

func _check_for_pickup() -> void:
	var space_state = get_world_3d().direct_space_state
	var from = global_position
	var to = from - global_transform.basis.z * PICKUP_RANGE

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2

	var result = space_state.intersect_ray(query)
	current_target = null
	prompt_label.visible = false

	if not result:
		# no input locking here; player movement should remain enabled
		pass
		return

	var collider = result.collider

	if collider.is_in_group("Pickupable"):
		current_target = collider
		prompt_label.visible = true
		prompt_label.text = "Press E to pick up " + current_target.item_name

	elif collider.is_in_group("CassettePlayer") and held_item:
		if not collider.held_cassette:
			current_target = collider
			prompt_label.visible = true
			prompt_label.text = "Press E to insert and play"


	elif collider.is_in_group("CassettePlayer") and not held_item and collider.held_cassette:
		current_target = collider
		prompt_label.visible = true
		prompt_label.text = "Press E to take cassette"


	elif collider.is_in_group("CopierSlot"):
		var text = collider.get_prompt_text(held_item)
		if text != "":
			current_target = collider
			prompt_label.visible = true
			prompt_label.text = text

func _input(event) -> void:
	if event.is_action_pressed("escape"):
		if keybind_panel:
			keybind_panel.visible = not keybind_panel.visible
			get_tree().set_meta("player_input_locked", keybind_panel.visible)
			hold_left = false
			hold_right = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if keybind_panel.visible else Input.MOUSE_MODE_CAPTURED
		return

	if keybind_panel and keybind_panel.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

	if event.is_action_pressed("pointer_left") and current_target and current_target.is_in_group("CassettePlayer"):
		pointer_index = max(pointer_index - 1, 0)
		var left := pointer_text.substr(0, pointer_index)
		var right := pointer_text.substr(pointer_index)
		playing_label.text = "\"" + left + "|" + right + "\""
		# arrow keys only seek; do not modify the assembled announcement (playback appends)
		# start hold repeat
		hold_left = true
		left_acc = 0.0
		return

	# seeking the recorder preview: move source preview when looking at source slot, blank preview when looking at blank slot
	if event.is_action_pressed("pointer_left") and current_target and current_target.is_in_group("CopierSlot") and cassette_recorder:
		if current_target == cassette_recorder.source_slot and cassette_recorder.has_method("seek_left"):
			cassette_recorder.seek_left()
			# start hold repeat
			hold_left = true
			left_acc = 0.0
		elif current_target == cassette_recorder.blank_slot and cassette_recorder.has_method("seek_blank_left"):
			cassette_recorder.seek_blank_left()
			# start hold repeat
			hold_left = true
			left_acc = 0.0
		return

	if event.is_action_pressed("pointer_right") and current_target and current_target.is_in_group("CassettePlayer"):
		pointer_index = min(pointer_index + 1, pointer_text.length())
		var left2 := pointer_text.substr(0, pointer_index)
		var right2 := pointer_text.substr(pointer_index)
		playing_label.text = "\"" + left2 + "|" + right2 + "\""
		# arrow keys only seek; do not modify the assembled announcement (playback appends)
		# if we've completed the full announcement, validate it
		if pointer_index >= pointer_text.length():
			if announcement_manager and announcement_manager.check_announcement(assembled_phrase_for_check):
				announcement_completed_correctly = true
				announcement_manager.correct_announcement.emit()
		# start hold repeat
		hold_right = true
		right_acc = 0.0
		return

	# track releases to stop holding
	if event.is_action_released("pointer_left"):
		hold_left = false

	if event.is_action_released("pointer_right"):
		hold_right = false

	# seeking the recorder preview: move source preview when looking at source slot, blank preview when looking at blank slot
	if event.is_action_pressed("pointer_right") and current_target and current_target.is_in_group("CopierSlot") and cassette_recorder:
		if current_target == cassette_recorder.source_slot and cassette_recorder.has_method("seek_right"):
			cassette_recorder.seek_right()
			# start hold repeat
			hold_right = true
			right_acc = 0.0
		elif current_target == cassette_recorder.blank_slot and cassette_recorder.has_method("seek_blank_right"):
			cassette_recorder.seek_blank_right()
			# start hold repeat
			hold_right = true
			right_acc = 0.0
		return

	if event.is_action_pressed("interact") and current_target:
		if current_target.is_in_group("Pickupable"):
			if held_item:
				held_item.drop()
				held_item = null
			current_target.pickup(hold_position)
			held_item = current_target

		elif current_target.is_in_group("CassettePlayer") and held_item:
			var inserted = current_target.insert(held_item)
			if inserted:
				held_item = null

		elif current_target.is_in_group("CassettePlayer") and not held_item and current_target.held_cassette:
			held_item = current_target.take(hold_position)
			if pointer_timer and pointer_timer.is_stopped() == false:
				pointer_timer.stop()
			pointer_index = 0
			playing_label.visible = false
			playing_label.text = ""
			is_playing = false
			# keep assembled phrase visible for a short duration, then clear it
			if announcement_timer:
				announcement_timer.start(playing_label_duration)
			# reset per-cassette appended counter when cassette removed
			current_cassette_appended_count = 0
			

		elif current_target.is_in_group("CopierSlot"):
			held_item = current_target.interact(held_item, hold_position)

		current_target = null
		prompt_label.visible = false

	if event.is_action_pressed("run") and current_target and current_target.is_in_group("CopierSlot"):
		current_target.get_parent().run_copy()

	if event.is_action_pressed("run") and current_target and current_target.is_in_group("CassettePlayer"):
		# If there's no announcement loaded, request it from the player.
		if not current_target.held_cassette:
			pass
		else:
			if pointer_text == "" or pointer_index >= pointer_text.length():
				# Load or replay the cassette from the beginning and reset the assembled buffer.
				current_target.play()
				assembled_phrase_for_check = ""
				current_announcement = ""
				current_cassette_appended_count = 0
				announcement_started = false
				# do not start automatic playback immediately
				is_playing = false
			else:
				# Toggle continuous playback: start/stop the pointer timer
				if not is_playing:
					# stop pending clear so assembled text remains during playback
					if announcement_timer and not announcement_timer.is_stopped():
						announcement_timer.stop()
					pointer_timer.wait_time = POINTER_STEP_TIME
					pointer_timer.start()
					is_playing = true
				else:
					if pointer_timer and not pointer_timer.is_stopped():
						pointer_timer.stop()
					is_playing = false

	if event.is_action_pressed("drop") and held_item:
		held_item.drop()
		held_item = null
	
	if event.is_action_pressed("reset"):
		# Only erase the blank cassette when looking at the recorder's blank slot
		if current_target and current_target.is_in_group("CopierSlot") and cassette_recorder and cassette_recorder.has_method("erase_blank"):
			if current_target == cassette_recorder.blank_slot:
				cassette_recorder.erase_blank()

	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * CAMERA_SENS
		rotation.x -= event.relative.y * CAMERA_SENS
		rotation.x = clamp(rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _add_to_announcement(phrase: String) -> void:
	if current_announcement == "":
		current_announcement = phrase
	else:
		current_announcement += " " + phrase

	# Update the assembled announcement UI (separate from the playing cassette text)
	if assembled_label:
		assembled_label.text = current_announcement
		assembled_label.visible = true

	# keep assembled buffer ready for checking (characters are appended as pointer moves)
	assembled_phrase_for_check = assembled_phrase_for_check

	pointer_timer.wait_time = POINTER_STEP_TIME


func _on_cassette_inserted(phrase: String) -> void:
	# Reset or keep the assembled announcement depending on the grace timer,
	# but do NOT concatenate the entire cassette phrase on insert — only characters
	# that are actually played should be appended.
	if announcement_timer and not announcement_timer.is_stopped():
		# within grace period: keep assembled_phrase_for_check as-is
		pass
	else:
		current_announcement = ""
		assembled_phrase_for_check = ""
		if assembled_label:
			assembled_label.text = ""
			assembled_label.visible = true
	# Do not auto-start playback on insert; require the player to press Run (F)
	# Update the playing cassette text separately so the playing label shows only current cassette
	current_cassette_text = phrase
	pointer_text = current_cassette_text
	pointer_index = 0
	announcement_completed_correctly = false
	announcement_started = false
	playing_label.text = "\"" + "|" + pointer_text + "\""
	playing_label.visible = true
	# reset per-cassette appended counter for the newly inserted cassette
	current_cassette_appended_count = 0


func _on_pointer_timeout() -> void:
	# advance pointer one character at a time
	pointer_index += 1
	if pointer_index > pointer_text.length():
		# reached end — stop pointer updates
		pointer_timer.stop()
		is_playing = false
		return

	var left := pointer_text.substr(0, pointer_index)
	var right := pointer_text.substr(pointer_index)
	playing_label.text = "\"" + left + "|" + right + "\""
	# append moved-over character to assembled phrase (per-cassette) and validate when complete
	if pointer_index > current_cassette_appended_count:
		var ch := pointer_text.substr(pointer_index - 1, 1)
		assembled_phrase_for_check += ch
		current_cassette_appended_count += 1
		announcement_started = true
		if assembled_label:
			assembled_label.text = assembled_phrase_for_check
			assembled_label.visible = true
		# Keep the assembled text visible while new characters arrive. The timer
		# is restarted after every appended character.
		if announcement_timer:
			announcement_timer.start(playing_label_duration)
	# Validate when the cassette has finished, without changing the inactivity timer.
	if pointer_index >= pointer_text.length():
		if announcement_manager and announcement_manager.check_announcement(assembled_phrase_for_check):
			announcement_completed_correctly = true
			announcement_manager.correct_announcement.emit()

func _on_recorder_slots_updated(source_phrase: String, blank_phrase: String, source_preview_index: int, blank_preview_index: int) -> void:
	# show source slot cassette in playing_label with preview cursor, and blank slot content in assembled_label with its own cursor
	if source_phrase == "":
		playing_label.visible = false
		playing_label.text = ""
	else:
		playing_label.visible = true
		var sidx = clamp(source_preview_index, 0, source_phrase.length())
		var sleft := source_phrase.substr(0, sidx)
		var sright := source_phrase.substr(sidx)
		playing_label.text = "\"" + sleft + "|" + sright + "\""

	if blank_phrase == "":
		assembled_label.visible = false
		assembled_label.text = ""
	else:
		assembled_label.visible = true
		var bidx = clamp(blank_preview_index, 0, blank_phrase.length())
		var bleft := blank_phrase.substr(0, bidx)
		var bright := blank_phrase.substr(bidx)
		assembled_label.text = bleft + "|" + bright

func _on_announcement_timer_timeout() -> void:
	# An expired incomplete announcement increases public confusion.
	if announcement_started and not announcement_completed_correctly:
		var game_manager = _get_game_manager()
		if game_manager and game_manager.has_method("change_confusion"):
			game_manager.change_confusion(10.0)
	announcement_completed_correctly = false
	# Clear the assembled phrase display after the timeout
	assembled_phrase_for_check = ""
	if assembled_label:
		assembled_label.text = ""
		assembled_label.visible = false
