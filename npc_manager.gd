extends Node3D
class_name NpcManager

const NPC_SCENE := preload("res://npc.tscn")
const MIN_NPCS := 4
const MAX_NPCS := 6
const SPAWN_WINDOW := 250.0
const LINE_SPACING := 0.7
const COACH_TYPES := ["General", "Sleeper", "AC Chair Car", "First Class"]
const NPC_CATEGORIES := ["child", "male", "female", "old"]

@export var game_manager: GameManager
@export var spawn_position := Vector3(7.2858715, 1.321737, 3.926077)

var spawn_timer: Timer
var spawn_times: Array[float] = []
var spawn_index := 0
var active_npcs: Array[Node3D] = []
var cycle_start_time_msec := 0
var all_npcs_served_emitted := false

signal all_npcs_served

func _ready() -> void:
	randomize()
	spawn_timer = Timer.new()
	spawn_timer.one_shot = true
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	if game_manager:
		game_manager.current_train_changed.connect(_on_current_train_changed)
		if game_manager.current_train:
			_start_cycle(game_manager.current_train)

func _on_current_train_changed(train: Train) -> void:
	_start_cycle(train)

func _start_cycle(train: Train) -> void:
	_clear_npcs()
	spawn_times.clear()
	spawn_index = 0
	all_npcs_served_emitted = false
	cycle_start_time_msec = Time.get_ticks_msec()
	if spawn_timer:
		spawn_timer.stop()
	if train.destinations.is_empty():
		return

	var npc_count := randi_range(MIN_NPCS, MAX_NPCS)
	for index in npc_count:
		spawn_times.append(randf_range(0.0, SPAWN_WINDOW))
	spawn_times.sort()
	_schedule_next_spawn()

func _schedule_next_spawn() -> void:
	if spawn_index >= spawn_times.size():
		return
	var elapsed: float = float(Time.get_ticks_msec() - cycle_start_time_msec) / 1000.0
	spawn_timer.start(maxf(0.0, spawn_times[spawn_index] - elapsed))

func _on_spawn_timer_timeout() -> void:
	if not game_manager or not game_manager.current_train:
		return
	_spawn_npc(game_manager.current_train)
	spawn_index += 1
	_schedule_next_spawn()

func _spawn_npc(train: Train) -> void:
	var npc := NPC_SCENE.instantiate() as Node3D
	add_child(npc)
	var destination: String = train.destinations.pick_random()
	var coach_type: String = COACH_TYPES.pick_random()
	var category: String = NPC_CATEGORIES.pick_random()
	npc.call("setup", destination, coach_type, category)
	npc.position = spawn_position + Vector3(-active_npcs.size() * LINE_SPACING, 0, 0)
	npc.connect("served", _on_npc_served)
	active_npcs.append(npc)

func get_remaining_npc_count() -> int:
	return active_npcs.size()

func _check_all_npcs_served() -> void:
	if not all_npcs_served_emitted and spawn_index >= spawn_times.size() and active_npcs.is_empty():
		all_npcs_served_emitted = true
		all_npcs_served.emit()

func _on_npc_served(npc: Node3D) -> void:
	active_npcs.erase(npc)
	_reposition_line()
	_check_all_npcs_served()

func _reposition_line() -> void:
	for index in active_npcs.size():
		if is_instance_valid(active_npcs[index]):
			active_npcs[index].position = spawn_position + Vector3(-index * LINE_SPACING, 0, 0)

func _clear_npcs() -> void:
	for npc in active_npcs:
		if is_instance_valid(npc):
			npc.queue_free()
	active_npcs.clear()
