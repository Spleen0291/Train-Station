extends Camera3D

const HIGHLIGHT_SHADER_CODE := """
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.0, 1.0, 0.8, 1.0);
uniform float outline_width = 2.0; // in pixels

void vertex() {
	vec4 clip_pos = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 clip_normal = mat3(PROJECTION_MATRIX) * (mat3(MODELVIEW_MATRIX) * NORMAL);
	vec2 offset = normalize(clip_normal.xy) / VIEWPORT_SIZE * clip_pos.w * outline_width * 2.0;
	clip_pos.xy += offset;
	POSITION = clip_pos;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
"""

@export var CAMERA_SENS = 0.003
@export var PICKUP_RANGE = 3.0
@export var prompt_label: Label
@export var playing_label: Label
@export var assembled_label: Label
@export var keybind_panel: Control
@export var map_overlay: TextureRect
@export var announcement_manager: AnnouncementManager
@export var hold_position: Node3D
@export var cassette_player: CassettePlayer
@export var cassette_recorder: Node
@export var playing_label_duration := 5.0
@export var POINTER_STEP_TIME := 0.15
@export var CASSETTE_SEEK_START_INTERVAL := 0.4
@export var CASSETTE_SEEK_MIN_INTERVAL := 0.04
@export var CASSETTE_SEEK_ACCELERATION_TIME := 3.0
@export var HOLD_REPEAT_INTERVAL := 0.1

@onready var player_mesh: MeshInstance3D = get_parent().get_node("MeshInstance3D")
var pointer_timer: Timer
var pointer_index: int = 0
var pointer_text: String = ""
var assembled_phrase_for_check: String = ""
@onready var announcement_timer: Timer = $AnnouncementTimer
var current_cassette_text: String = ""
var current_cassette_appended_count: int = 0

var current_target: Node3D = null
var active_mouse_hold_button: Node = null
var current_target_shape := -1
var current_target_position := Vector3.ZERO
var held_item: Node3D = null
var current_announcement := ""
var is_playing: bool = false
var announcement_completed_correctly: bool = false
var announcement_started: bool = false
var hold_left: bool = false
var hold_right: bool = false
var cassette_seek_direction: int = 0
var cassette_seek_elapsed := 0.0
var cassette_seek_interval := 0.0
var left_acc: float = 0.0
var right_acc: float = 0.0
var last_train_key: String = ""
var normal_camera_transform: Transform3D
var inspection_return_transform: Transform3D
var inspection_view := ""
var camera_is_fixed := false
var highlighted_target: Node3D = null
var highlighted_overlays: Dictionary = {}
var highlight_material: ShaderMaterial

func _ready() -> void:
	normal_camera_transform = transform
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().set_meta("player_input_locked", false)
	var highlight_shader := Shader.new()
	highlight_shader.code = HIGHLIGHT_SHADER_CODE
	highlight_material = ShaderMaterial.new()
	highlight_material.shader = highlight_shader
	var game_manager = _get_game_manager()
	if game_manager:
		last_train_key = _get_train_key(game_manager)
	if cassette_player:
		cassette_player.cassette_inserted.connect(_on_cassette_inserted)
		cassette_player.cassette_removed.connect(_on_cassette_removed)
		cassette_player.recording_mode_changed.connect(_on_recording_mode_changed)
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
			if current_target and current_target.is_in_group("CassettePlayer") and not _is_recorder_control_target(current_target):
				pointer_index = max(pointer_index - 1, 0)
				var left := pointer_text.substr(0, pointer_index)
				var right := pointer_text.substr(pointer_index)
				cassette_player.set_content_display("\"" + left + "|" + right + "\"")
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
			if current_target and current_target.is_in_group("CassettePlayer") and not _is_recorder_control_target(current_target):
				pointer_index = min(pointer_index + 1, pointer_text.length())
				var left2 := pointer_text.substr(0, pointer_index)
				var right2 := pointer_text.substr(pointer_index)
				cassette_player.set_content_display("\"" + left2 + "|" + right2 + "\"")
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

func _is_recorder_control_target(target: Node3D) -> bool:
	return cassette_recorder != null and target != null and target.get_parent() == cassette_recorder

func _is_cassette_rack_target(target: Node3D) -> bool:
	var node: Node = target
	while node:
		if node.is_in_group("CassetteRack") or node.is_in_group("Rack") or "rack" in node.name.to_lower():
			return true
		node = node.get_parent()
	return false

func set_camera_transform(camera_transform: Transform3D) -> void:
	set_inspection_camera(camera_transform)

func is_camera_fixed() -> bool:
	return camera_is_fixed

func move_fixed_camera_to_position(target_position: Vector3) -> void:
	if not camera_is_fixed:
		return
	var ticket_system := get_tree().get_first_node_in_group("TicketSystem") as TicketSystem
	if ticket_system == null:
		return
	var rack_camera_transform := ticket_system.camera_position.global_transform
	global_transform = rack_camera_transform
	global_position = Vector3(target_position.x, target_position.y + 0.3, rack_camera_transform.origin.z + 0.2)
	global_rotation.x += deg_to_rad(-10.0)
	inspection_view = "ticket_stack"

func set_inspection_camera(camera_transform: Transform3D, view_name := "") -> void:
	if not camera_is_fixed:
		inspection_return_transform = global_transform
	global_transform = camera_transform
	camera_is_fixed = true
	inspection_view = view_name
	player_mesh.visible = false
	get_tree().set_meta("player_input_locked", true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func restore_camera_transform() -> void:
	if not camera_is_fixed:
		return
	global_transform = inspection_return_transform
	camera_is_fixed = false
	inspection_view = ""
	var announcement_system := get_tree().get_first_node_in_group("AnnouncementSystem")
	if announcement_system and announcement_system.has_method("deactivate"):
		announcement_system.deactivate()
	var cassette_rack := get_tree().get_first_node_in_group("CassetteRack")
	if cassette_rack and cassette_rack.has_method("deactivate"):
		cassette_rack.deactivate()
	var ticket_system := get_tree().get_first_node_in_group("TicketSystem")
	if ticket_system and ticket_system.has_method("deactivate"):
		ticket_system.deactivate()
	player_mesh.visible = true
	get_tree().set_meta("player_input_locked", false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _switch_inspection_view(view_name: String) -> void:
	if not camera_is_fixed or inspection_view == view_name:
		return
	var target: Node = null
	if view_name == "announcement":
		target = get_tree().get_first_node_in_group("AnnouncementSystem")
	elif view_name == "rack":
		target = get_tree().get_first_node_in_group("CassetteRack")
	elif view_name == "ticket_system" or view_name == "ticket_table" or view_name == "ticket_npc":
		target = get_tree().get_first_node_in_group("TicketSystem")
	if target == null:
		return
	var marker_name := "Camera Position"
	if view_name == "ticket_system":
		marker_name = "Cabinet Camera Position"
	elif view_name == "ticket_table":
		marker_name = "Table Camera Position"
	elif view_name == "ticket_npc":
		marker_name = "NPC Camera Position"
	var marker := target.get_node_or_null(marker_name) as Marker3D
	if marker == null:
		return
	global_transform = marker.global_transform
	inspection_view = view_name

func play_cassette_button(_player: CassettePlayer) -> void:
	if is_playing:
		_stop_cassette_action()
		return
	_stop_cassette_action()
	cassette_seek_direction = 0
	if pointer_text == "" or pointer_index >= pointer_text.length():
		_player.play()
		assembled_phrase_for_check = ""
		current_announcement = ""
		current_cassette_appended_count = 0
		announcement_started = false
		is_playing = false
		return
	if not is_playing:
		if announcement_timer and not announcement_timer.is_stopped():
			announcement_timer.stop()
		pointer_timer.wait_time = POINTER_STEP_TIME
		pointer_timer.start()
		is_playing = true

func rewind_cassette_button(_player: CassettePlayer) -> void:
	if cassette_seek_direction == -1:
		_stop_cassette_action()
		return
	_stop_cassette_action()
	_start_cassette_seek(-1)

func forward_cassette_button(_player: CassettePlayer) -> void:
	if cassette_seek_direction == 1:
		_stop_cassette_action()
		return
	_stop_cassette_action()
	_start_cassette_seek(1)

func stop_cassette_transport() -> void:
	_stop_cassette_action()

func _stop_cassette_action() -> void:
	cassette_seek_direction = 0
	cassette_seek_elapsed = 0.0
	if pointer_timer and not pointer_timer.is_stopped():
		pointer_timer.stop()
	is_playing = false

func _start_cassette_seek(direction: int) -> void:
	cassette_seek_direction = direction
	cassette_seek_elapsed = 0.0
	cassette_seek_interval = CASSETTE_SEEK_START_INTERVAL
	is_playing = false
	_seek_cassette_pointer()
	pointer_timer.wait_time = cassette_seek_interval
	pointer_timer.start()

func _get_cassette_seek_interval() -> float:
	var progress := clampf(cassette_seek_elapsed / CASSETTE_SEEK_ACCELERATION_TIME, 0.0, 1.0)
	return lerpf(CASSETTE_SEEK_START_INTERVAL, CASSETTE_SEEK_MIN_INTERVAL, progress)

func _release_active_mouse_hold() -> void:
	if is_instance_valid(active_mouse_hold_button):
		active_mouse_hold_button.release_hold(self)
	active_mouse_hold_button = null

func _seek_cassette_pointer() -> void:
	pointer_index = clamp(pointer_index + cassette_seek_direction, 0, pointer_text.length())
	current_cassette_appended_count = pointer_index
	_update_pointer_label()

func _update_pointer_label() -> void:
	var left := pointer_text.substr(0, pointer_index)
	var right := pointer_text.substr(pointer_index)
	cassette_player.set_content_display("\"" + left + "|" + right + "\"")

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
	var from: Vector3
	var to: Vector3
	if camera_is_fixed:
		var mouse_position := get_viewport().get_mouse_position()
		from = project_ray_origin(mouse_position)
		to = from + project_ray_normal(mouse_position) * PICKUP_RANGE
	else:
		from = global_position
		to = from - global_transform.basis.z * PICKUP_RANGE

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 2 | 4
	query.collide_with_areas = true
	var excluded_rids: Array[RID] = []
	var cassette_rack: Node3D = null
	var ticket_system := get_tree().get_first_node_in_group("TicketSystem")
	if camera_is_fixed:
		cassette_rack = get_tree().get_first_node_in_group("CassetteRack")
		if cassette_rack:
			excluded_rids.append(cassette_rack.get_rid())
		if not held_item and ticket_system:
			excluded_rids.append(ticket_system.get_rid())
	query.exclude = excluded_rids

	var result = space_state.intersect_ray(query)
	if camera_is_fixed and held_item is Ticket:
		var npc_query := PhysicsRayQueryParameters3D.create(from, to)
		npc_query.collision_mask = 1
		npc_query.collide_with_areas = false
		if ticket_system:
			npc_query.exclude = [ticket_system.get_rid()]
		var npc_result = space_state.intersect_ray(npc_query)
		if npc_result and npc_result.collider.has_method("accept_ticket"):
			result = npc_result
		if ticket_system and (not result or result.collider == ticket_system):
			var calculator_query := PhysicsRayQueryParameters3D.create(from, to)
			calculator_query.collision_mask = 1
			calculator_query.collide_with_areas = false
			calculator_query.exclude = [ticket_system.get_rid()]
			var calculator_result = space_state.intersect_ray(calculator_query)
			if calculator_result and calculator_result.collider.is_in_group("Calculator"):
				result = calculator_result
	if camera_is_fixed and held_item is Ticket and ticket_system and result and result.collider == ticket_system:
		var stamp_query := PhysicsRayQueryParameters3D.create(from, to)
		stamp_query.collision_mask = 2
		stamp_query.collide_with_areas = false
		stamp_query.exclude = [ticket_system.get_rid()]
		var stamp_result = space_state.intersect_ray(stamp_query)
		if stamp_result and stamp_result.collider.is_in_group("Stamp"):
			result = stamp_result
	if camera_is_fixed and held_item and cassette_rack:
		var rack_query := PhysicsRayQueryParameters3D.create(from, to)
		rack_query.collision_mask = 1
		var rack_result = space_state.intersect_ray(rack_query)
		if rack_result and rack_result.collider == cassette_rack:
			if not result or not result.collider.is_in_group("Pickupable"):
				result = rack_result
	current_target = null
	current_target_shape = -1
	current_target_position = Vector3.ZERO
	prompt_label.visible = false

	if not result:
		# no input locking here; player movement should remain enabled
		_update_target_highlight(null)
		return

	var collider = result.collider
	current_target_shape = result.shape if collider is TicketSystem else -1
	current_target_position = result.position
	if not camera_is_fixed:
		var player_query := PhysicsRayQueryParameters3D.create(from, to)
		player_query.collision_mask = 1
		var player_result = space_state.intersect_ray(player_query)
		if player_result and player_result.collider.is_in_group("CassettePlayer"):
			collider = player_result.collider
	elif collider.is_in_group("CassettePlayer"):
		var button_query := PhysicsRayQueryParameters3D.create(from, to)
		button_query.collision_mask = 4
		button_query.exclude = [collider.get_rid()]
		var button_result = space_state.intersect_ray(button_query)
		if button_result and button_result.collider.has_method("get_interaction_prompt"):
			var button_prompt: String = button_result.collider.get_interaction_prompt(self)
			if button_prompt != "":
				collider = button_result.collider

	if collider.is_in_group("Stamp"):
		current_target = collider
		prompt_label.visible = true
		if collider.has_method("get_interaction_prompt"):
			prompt_label.text = collider.get_interaction_prompt(self)
		elif held_item is Ticket:
			prompt_label.text = "Left click to print fare"
		else:
			prompt_label.text = "Hold a ticket and left click to print fare"

	elif collider.is_in_group("Calculator"):
		if collider.has_method("get_interaction_prompt"):
			var calculator_prompt: String = collider.get_interaction_prompt(self)
			if calculator_prompt != "":
				current_target = collider
				prompt_label.visible = true
				prompt_label.text = calculator_prompt

	elif camera_is_fixed and collider.is_in_group("Pickupable"):
		current_target = collider
		prompt_label.visible = true
		prompt_label.text = "Left click to pick up " + current_target.item_name

	elif _is_cassette_rack_target(collider) and held_item:
		current_target = collider
		prompt_label.visible = true
		prompt_label.text = "Left click to return cassette"

	elif collider.has_method("accept_ticket") and held_item is Ticket:
		current_target = collider
		prompt_label.visible = true
		prompt_label.text = "Left click to give ticket"

	elif collider.is_in_group("RouteMap"):
		current_target = collider
		prompt_label.visible = true
		prompt_label.text = "Hold right click to inspect map"

	elif collider is TicketSystem:
		var ticket_system_prompt: String = collider.get_interaction_prompt(self, current_target_shape, current_target_position)
		if ticket_system_prompt != "":
			current_target = collider
			prompt_label.visible = true
			prompt_label.text = ticket_system_prompt

	elif collider.has_method("get_interaction_prompt"):
		var interaction_prompt : String = collider.get_interaction_prompt(self)
		if interaction_prompt != "":
			current_target = collider
			prompt_label.visible = true
			prompt_label.text = interaction_prompt

	elif collider.is_in_group("CopierSlot"):
		var text = collider.get_prompt_text(held_item)
		if text != "":
			current_target = collider
			prompt_label.visible = true
			prompt_label.text = text

	_update_target_highlight(current_target)

func _update_target_highlight(target: Node3D) -> void:
	if highlighted_target == target:
		return
	_clear_target_highlight()
	if target == null or highlight_material == null:
		return

	var geometry_nodes: Array[GeometryInstance3D] = []
	_collect_geometry_nodes(target, geometry_nodes)
	for geometry in geometry_nodes:
		highlighted_overlays[geometry] = geometry.material_overlay
		geometry.material_overlay = highlight_material
	highlighted_target = target

func _clear_target_highlight() -> void:
	for geometry in highlighted_overlays:
		if is_instance_valid(geometry):
			geometry.material_overlay = highlighted_overlays[geometry]
	highlighted_overlays.clear()
	highlighted_target = null

func _collect_geometry_nodes(node: Node, result: Array[GeometryInstance3D]) -> void:
	if node is Label3D:
		return
	if node is GeometryInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect_geometry_nodes(child, result)

func _input(event) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_release_active_mouse_hold()

	if event.is_action_pressed("escape"):
		if camera_is_fixed:
			restore_camera_transform()
			current_target = null
			prompt_label.visible = false
			return
		if keybind_panel:
			keybind_panel.visible = not keybind_panel.visible
			get_tree().set_meta("player_input_locked", keybind_panel.visible)
			hold_left = false
			hold_right = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if keybind_panel.visible else Input.MOUSE_MODE_CAPTURED
		return

	if keybind_panel and keybind_panel.visible:
		return

	if camera_is_fixed:
		if event.is_action_pressed("move_forward") and inspection_view == "ticket_table":
			_switch_inspection_view("ticket_npc")
			return
		if event.is_action_pressed("move_back") and inspection_view == "ticket_npc":
			_switch_inspection_view("ticket_table")
			return
		if event.is_action_pressed("move_right") and inspection_view == "ticket_system":
			_switch_inspection_view("ticket_table")
			return
		if event.is_action_pressed("move_left") and inspection_view == "ticket_table":
			_switch_inspection_view("ticket_system")
			return
		if event.is_action_pressed("move_right") and inspection_view == "announcement":
			_switch_inspection_view("rack")
			return
		if event.is_action_pressed("move_left") and inspection_view == "rack":
			_switch_inspection_view("announcement")
			return

	if event.is_action_pressed("run") and current_target and current_target.is_in_group("Stamp"):
		_stamp_ticket(current_target)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and held_item is Ticket:
		if event.pressed:
			held_item.show_inspection()
		else:
			held_item.hide_inspection()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and map_overlay:
		if event.pressed and current_target and current_target.is_in_group("RouteMap"):
			map_overlay.visible = true
			return
		if not event.pressed and map_overlay.visible:
			map_overlay.visible = false
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and current_target:
		if _is_cassette_rack_target(current_target) and held_item and held_item.has_method("drop"):
			held_item.drop()
			held_item = null
			current_target = null
			prompt_label.visible = false
			return
		if current_target.has_method("accept_ticket") and held_item is Ticket:
			_give_ticket_to_npc(current_target)
			return
		if current_target.has_method("activate"):
			var activated_target := current_target
			var activation_succeeded: bool
			if current_target is TicketSystem:
				activation_succeeded = current_target.activate(self, current_target_shape, current_target_position)
			else:
				activation_succeeded = current_target.activate(self)
			if activation_succeeded and activated_target.has_method("release_hold"):
				active_mouse_hold_button = activated_target
			current_target = null
			prompt_label.visible = false
			return

	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

	if event.is_action_pressed("pointer_left") and current_target and current_target.is_in_group("CassettePlayer") and not _is_recorder_control_target(current_target):
		pointer_index = max(pointer_index - 1, 0)
		var left := pointer_text.substr(0, pointer_index)
		var right := pointer_text.substr(pointer_index)
		cassette_player.set_content_display("\"" + left + "|" + right + "\"")
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

	if event.is_action_pressed("pointer_right") and current_target and current_target.is_in_group("CassettePlayer") and not _is_recorder_control_target(current_target):
		pointer_index = min(pointer_index + 1, pointer_text.length())
		var left2 := pointer_text.substr(0, pointer_index)
		var right2 := pointer_text.substr(pointer_index)
		cassette_player.set_content_display("\"" + left2 + "|" + right2 + "\"")
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
		if current_target.has_method("accept_ticket") and held_item is Ticket:
			_give_ticket_to_npc(current_target)

		elif current_target.is_in_group("CopierSlot"):
			held_item = current_target.interact(held_item, hold_position)

		current_target = null
		prompt_label.visible = false

	if event.is_action_pressed("run") and current_target and current_target.is_in_group("CopierSlot"):
		current_target.get_parent().run_copy(self)

	if event.is_action_pressed("reset"):
		# Only erase the blank cassette when looking at the recorder's blank slot
		if current_target and current_target.is_in_group("CopierSlot") and cassette_recorder and cassette_recorder.has_method("erase_blank"):
			if current_target == cassette_recorder.blank_slot:
				cassette_recorder.erase_blank()

	if event is InputEventMouseMotion and not camera_is_fixed:
		rotation.y -= event.relative.x * CAMERA_SENS
		rotation.x -= event.relative.y * CAMERA_SENS
		rotation.x = clamp(rotation.x, deg_to_rad(-80), deg_to_rad(80))

func _give_ticket_to_npc(npc: Node) -> void:
	var game_manager := _get_game_manager()
	var submitted_ticket: Ticket = held_item
	if npc.has_method("print_ticket_comparison"):
		npc.print_ticket_comparison(submitted_ticket)
	var ticket_accepted: bool = npc.accept_ticket(submitted_ticket)
	if ticket_accepted:
		if game_manager:
			game_manager.change_confusion_percent(-5.0)
	elif game_manager:
		game_manager.change_confusion_percent(15.0)
	submitted_ticket.consume()
	held_item = null
	current_target = null
	prompt_label.visible = false

func _stamp_ticket(stamp: Node3D) -> void:
	if held_item is Ticket and stamp.stamp_ticket(held_item):
		prompt_label.text = "Ticket stamped"

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
	cassette_seek_direction = 0
	pointer_text = current_cassette_text
	pointer_index = 0
	announcement_completed_correctly = false
	announcement_started = false
	cassette_player.set_content_display("\"" + "|" + pointer_text + "\"")
	# reset per-cassette appended counter for the newly inserted cassette
	current_cassette_appended_count = 0


func _on_cassette_removed(_cassette: Node3D) -> void:
	if pointer_timer and not pointer_timer.is_stopped():
		pointer_timer.stop()
	pointer_index = 0
	cassette_player.set_content_display("")
	is_playing = false
	cassette_seek_direction = 0
	if announcement_timer:
		announcement_timer.start(playing_label_duration)
	current_cassette_appended_count = 0


func _on_pointer_timeout() -> void:
	if cassette_seek_direction != 0:
		_seek_cassette_pointer()
		cassette_seek_elapsed += cassette_seek_interval
		cassette_seek_interval = _get_cassette_seek_interval()
		pointer_timer.start(cassette_seek_interval)
		return

	# advance pointer one character at a time
	pointer_index += 1
	if pointer_index > pointer_text.length():
		# reached end — stop pointer updates
		pointer_timer.stop()
		is_playing = false
		return

	var left := pointer_text.substr(0, pointer_index)
	var right := pointer_text.substr(pointer_index)
	cassette_player.set_content_display("\"" + left + "|" + right + "\"")
	# append moved-over character to assembled phrase (per-cassette) and validate when complete
	if pointer_index > current_cassette_appended_count:
		var ch := pointer_text.substr(pointer_index - 1, 1)
		assembled_phrase_for_check += ch
		current_cassette_appended_count += 1
		announcement_started = true
		if playing_label:
			playing_label.text = assembled_phrase_for_check
			playing_label.visible = true
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
	if not cassette_recorder:
		return
	if cassette_recorder.is_copying and cassette_player:
		if source_phrase == "" and cassette_player.held_cassette:
			source_phrase = cassette_player.held_cassette.phrase
		var source_index: int = clampi(source_preview_index, 0, source_phrase.length())
		pointer_index = source_index
		pointer_text = source_phrase
		var source_left := source_phrase.substr(0, source_index)
		var source_right := source_phrase.substr(source_index)
		cassette_player.set_content_display("\"" + source_left + "|" + source_right + "\"")
	if blank_phrase == "":
		cassette_recorder.set_content_display("")
	else:
		var bidx = clamp(blank_preview_index, 0, blank_phrase.length())
		var bleft := blank_phrase.substr(0, bidx)
		var bright := blank_phrase.substr(bidx)
		cassette_recorder.set_content_display(bleft + "|" + bright)

func _on_recording_mode_changed(active: bool) -> void:
	if active:
		var source_phrase := ""
		var blank_phrase := ""
		if cassette_player and cassette_player.held_cassette:
			source_phrase = cassette_player.held_cassette.phrase
		if cassette_recorder and cassette_recorder.get("held_cassette"):
			blank_phrase = cassette_recorder.get("held_cassette").phrase
		var blank_index := int(cassette_recorder.get("blank_index")) if cassette_recorder else 0
		_on_recorder_slots_updated(source_phrase, blank_phrase, pointer_index, blank_index)
		return
	if cassette_player:
		if cassette_player.held_cassette and cassette_player.cassette_seated:
			current_cassette_text = cassette_player.held_cassette.phrase
			pointer_text = current_cassette_text
			pointer_index = clamp(pointer_index, 0, pointer_text.length())
			var left := pointer_text.substr(0, pointer_index)
			var right := pointer_text.substr(pointer_index)
			cassette_player.set_content_display("\"" + left + "|" + right + "\"")
		else:
			cassette_player.set_content_display("")
	if cassette_recorder:
		if cassette_recorder.get("held_cassette"):
			var recorder_phrase: String = cassette_recorder.get("held_cassette").phrase
			var recorder_index: int = clampi(int(cassette_recorder.get("blank_index")), 0, recorder_phrase.length())
			var recorder_left := recorder_phrase.substr(0, recorder_index)
			var recorder_right := recorder_phrase.substr(recorder_index)
			cassette_recorder.set_content_display(recorder_left + "|" + recorder_right)
		else:
			cassette_recorder.set_content_display("")

func _on_announcement_timer_timeout() -> void:
	# An expired incomplete announcement increases public confusion.
	if announcement_started and not announcement_completed_correctly:
		var game_manager = _get_game_manager()
		if game_manager and game_manager.has_method("change_confusion"):
			game_manager.change_confusion(10.0)
	announcement_completed_correctly = false
	# Clear the playing announcement display after the timeout
	assembled_phrase_for_check = ""
	if playing_label:
		playing_label.text = ""
		playing_label.visible = false
