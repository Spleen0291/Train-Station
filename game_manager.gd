extends Node3D
class_name GameManager

const TASK_TIME := 180.0

@export var announcement_manager: AnnouncementManager
@export var departure_board: DepartureBoard
@onready var task_timer: Timer = $TaskTimer
@export var timerLabel: Label
@export var confusion_bar: ProgressBar

var current_day: int = 1
var current_train_index: int = 0
var current_train: Train
var failure_count: int = 0

var task_completed: bool = false
var game_active: bool = false	
var blank_cassettes: Array[Node3D] = []

func change_confusion(amount: float) -> void:
	if confusion_bar:
		var next_value := confusion_bar.value + amount
		if next_value >= 100.0:
			confusion_bar.value = 0.0
			_remove_blank_cassette()
		else:
			confusion_bar.value = clamp(next_value, 0.0, 100.0)

func _remove_blank_cassette() -> void:
	for cassette in blank_cassettes:
		if is_instance_valid(cassette):
			print("CONFUSION MAXIMUM: removing ", cassette.name)
			cassette.queue_free()
			blank_cassettes.erase(cassette)
			return

func start_game() -> void:
	current_day = 1
	current_train_index = 0
	failure_count = 0

	game_active = true

	start_current_train()

func start_current_train() -> void:

	var trains: Array[Train] = ScheduleDatabase.get_trains(current_day)

	if current_train_index >= trains.size():
		complete_current_day()
		return

	current_train = trains[current_train_index]

	task_completed = false

	departure_board.display_train(current_train)

	# Start 120-second timer
	task_timer.start(TASK_TIME)
	
func complete_current_day() -> void:

	print("DAY ", current_day, " COMPLETE")

	current_day += 1
	current_train_index = 0

	if current_day > 7:
		end_game()
		return

	start_current_train()

func end_game() -> void:

	game_active = false

	task_timer.stop()

	print("GAME COMPLETE")
	print("TOTAL FAILURES: ", failure_count)

func _on_task_timer_timeout() -> void:
	if not game_active:
		return

	if task_completed:
		return

	print("TIME EXPIRED")

	failure_count += 1
	change_confusion(50.0)

	print("FAILURES: ", failure_count)

	finish_current_train()

func finish_current_train() -> void:

	current_train_index += 1

	start_current_train()

func _on_correct_announcement() -> void:
	task_completed = true
	change_confusion(-20.0)
	finish_current_train()

func _on_timer_timeout() -> void:
	return

func quit_game() -> void:
	get_tree().quit()

func reset_world() -> void:
	get_tree().reload_current_scene()

func _ready() -> void:
	for cassette_name in ["Blank", "Blank1", "Blank2", "Blank3", "Blank4", "Blank5"]:
		var cassette = get_parent().get_node_or_null(cassette_name)
		if cassette:
			blank_cassettes.append(cassette)
	if confusion_bar:
		confusion_bar.value = 0.0
	start_game()
	announcement_manager.correct_announcement.connect(_on_correct_announcement)
	

func _process(delta: float) -> void:
	timerLabel.text = str(int(task_timer.time_left))
