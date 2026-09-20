extends Node3D
class_name TicketRequestBoard

@export var destination: String = "Delhi"
@export var coach_type: String = "Sleeper"
@export var game_manager: GameManager

signal request_changed(destination: String, coach_type: String)

@onready var destination_label: Label = $SubViewport/MessageBox/VBoxContainer/DestinationLabel
@onready var coach_label: Label = $SubViewport/MessageBox/VBoxContainer/CoachLabel

func _ready() -> void:
	if game_manager:
		game_manager.current_train_changed.connect(_on_current_train_changed)
		if game_manager.current_train:
			_on_current_train_changed(game_manager.current_train)
	else:
		display_request(destination, coach_type)

func _on_current_train_changed(train: Train) -> void:
	if train.destinations.is_empty():
		return
	display_request(train.destinations.pick_random(), coach_type)

func display_request(requested_destination: String, requested_coach_type: String) -> void:
	destination = requested_destination
	coach_type = requested_coach_type
	if not is_node_ready():
		return
	destination_label.text = "To: " + destination
	coach_label.text = "Coach: " + coach_type
	request_changed.emit(destination, coach_type)
