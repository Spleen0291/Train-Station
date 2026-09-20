extends Node3D
class_name TicketBoard

const TICKET_SCENE := preload("res://scenes/ticket_system/ticket.tscn")
const COLUMNS := 8
const COLUMN_SPACING := 0.18
const ROW_SPACING := 0.2
const TICKET_SCALE := 0.42

@export var from_station: String = "Kaalnagar"
@export var coach_type: String = ""

func _ready() -> void:
	_build_destination_grid()

func _build_destination_grid() -> void:
	var destinations := ScheduleDatabase.get_unique_destinations()
	var row_count := ceili(float(destinations.size()) / COLUMNS)
	var start_x: float = -((min(destinations.size(), COLUMNS) - 1) * COLUMN_SPACING) / 2.0
	var start_y: float = ((row_count - 1) * ROW_SPACING) / 2.0

	for index in destinations.size():
		var column := index % COLUMNS
		var row := index / COLUMNS
		var ticket_position := Vector3(start_x + column * COLUMN_SPACING, start_y - row * ROW_SPACING, 0.05)
		_create_cabinet_ticket(destinations[index], ticket_position)

func _create_cabinet_ticket(destination: String, ticket_position: Vector3) -> void:
	var ticket := TICKET_SCENE.instantiate() as Ticket
	add_child(ticket)
	ticket.from_station = from_station
	ticket.cabinet_ticket = true
	ticket.cabinet_position = ticket_position
	ticket.position = ticket_position
	ticket.scale = Vector3.ONE * TICKET_SCALE
	ticket.display_ticket(destination, coach_type)
	ticket.picked_up.connect(_on_cabinet_ticket_picked_up)

func _on_cabinet_ticket_picked_up(ticket: Ticket) -> void:
	_create_cabinet_ticket(ticket.to_station, ticket.cabinet_position)
