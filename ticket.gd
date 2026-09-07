extends StaticBody3D
class_name Ticket

@export var from_station: String = "Trian Station"
@export var to_station: String = "Delhi"
@export var coach_type: String = ""
@export var fare_price: int = -1
@export var request_board: TicketRequestBoard
@export var item_name: String = "Ticket"

signal picked_up(ticket: Ticket)

var is_held := false
var original_parent: Node3D = null
var original_transform: Transform3D
var cabinet_ticket := false
var cabinet_position := Vector3.ZERO

@onready var ticket_background: ColorRect = $SubViewport/TicketUI/TicketBackground
@onready var from_label: Label = $SubViewport/TicketUI/Content/FromLabel
@onready var to_label: Label = $SubViewport/TicketUI/Content/ToLabel
@onready var fare_label: Label = $SubViewport/TicketUI/Content/FareLabel
@onready var coach_label: Label = $SubViewport/TicketUI/Content/CoachLabel
@onready var inspect_overlay: Control = $InspectionLayer/InspectOverlay
@onready var destination_label: Label3D = $DestinationLabel

func _ready() -> void:
	if request_board == null:
		request_board = get_node_or_null("../npc/TicketRequestBoard") as TicketRequestBoard
	if request_board:
		request_board.request_changed.connect(_on_request_changed)
		_on_request_changed(request_board.destination, request_board.coach_type)
	else:
		display_ticket(to_station, coach_type)

func _on_request_changed(requested_destination: String, requested_coach_type: String) -> void:
	display_ticket(requested_destination, requested_coach_type)

func display_ticket(requested_destination: String, requested_coach_type: String) -> void:
	to_station = requested_destination
	coach_type = requested_coach_type
	if not is_node_ready():
		return
	from_label.text = "FROM: " + from_station
	to_label.text = "TO: " + to_station
	fare_price = -1
	_update_fare_label()
	coach_label.text = "COACH: " + coach_type
	ticket_background.color = _get_coach_color(coach_type)
	destination_label.text = to_station

func set_fare(new_fare: int) -> void:
	fare_price = new_fare
	_update_fare_label()

func set_coach(new_coach: String) -> void:
	coach_type = new_coach
	if not is_node_ready():
		return
	coach_label.text = "COACH: " + coach_type
	ticket_background.color = _get_coach_color(coach_type)

func _update_fare_label() -> void:
	if fare_price < 0:
		fare_label.text = "FARE:"
	else:
		fare_label.text = "FARE: Rs. " + str(fare_price)

func _get_coach_color(requested_coach_type: String) -> Color:
	match requested_coach_type.to_lower():
		"general":
			return Color("60a461ff")
		"sleeper":
			return Color("#78b7e8")
		"ac chair car":
			return Color("#e8c66d")
		"first class":
			return Color("#d98b4a")
		_:
			return Color("f4f5f7ff")

func pickup(hold_position: Node3D) -> void:
	if is_held:
		return
	is_held = true

	original_parent = get_parent()
	original_transform = global_transform
	remove_from_group("Pickupable")
	collision_layer = 0
	collision_mask = 0
	attach_to(hold_position)
	picked_up.emit(self)

func show_inspection() -> void:
	if is_held:
		inspect_overlay.visible = true

func hide_inspection() -> void:
	inspect_overlay.visible = false

func drop() -> void:
	if not is_held:
		return
	is_held = false
	hide_inspection()
	if cabinet_ticket:
		queue_free()
		return

	attach_to(original_parent)
	global_transform = original_transform
	add_to_group("Pickupable")
	collision_layer = 2
	collision_mask = 1

func consume() -> void:
	is_held = false
	hide_inspection()
	queue_free()

func attach_to(parent: Node3D) -> void:
	var current_parent = get_parent()
	if current_parent:
		current_parent.remove_child(self)
	parent.add_child(self)
	position = Vector3.ZERO
	rotation = Vector3(0, PI, 0) if is_held else Vector3.ZERO
