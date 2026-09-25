extends Node3D
class_name TicketStack

const TICKET_SCENE := preload("res://scenes/ticket_system/ticket.tscn")

@export var destination: String = ""
@export var coach_type: String = ""
@export var destination_label_enabled := true

var base_position := Vector3.ZERO

@onready var destination_label: Label3D = $DestinationLabel

func _ready() -> void:
	base_position = position
	destination_label.visible = destination_label_enabled
	_update_destination_label()

func setup(requested_destination: String, requested_coach_type: String, show_destination_label: bool = true) -> void:
	destination = requested_destination
	coach_type = requested_coach_type
	base_position = position
	destination_label_enabled = show_destination_label
	destination_label.visible = show_destination_label
	_update_destination_label()

func get_interaction_prompt(actor: Node, _requested_coach_type: String = coach_type) -> String:
	if not _can_interact(actor) or actor.held_item:
		return ""
	var rack := get_parent() as TicketStackRack
	if rack == null:
		return ""
	if not rack.is_destination_selected(destination):
		return "Left click to select " + destination
	return "Left click to take " + destination + " ticket"

func activate(actor: Node, requested_coach_type: String = coach_type, requested_ticket_position := Vector3.ZERO) -> bool:
	if not _can_interact(actor) or actor.held_item:
		return false
	var rack := get_parent() as TicketStackRack
	if rack == null:
		return false
	if not rack.is_destination_selected(destination):
		rack.select_destination(destination)
		if actor.has_method("move_fixed_camera_to_position"):
			actor.move_fixed_camera_to_position(global_position)
		return true

	var ticket := TICKET_SCENE.instantiate() as Ticket
	if ticket == null:
		return false

	get_parent().add_child(ticket)
	ticket.global_position = global_position if requested_ticket_position == Vector3.ZERO else requested_ticket_position
	ticket.display_ticket(destination, requested_coach_type)
	ticket.pickup(actor.hold_position)
	actor.held_item = ticket
	rack.clear_selection()
	var ticket_system := rack.get_parent() as TicketSystem
	if ticket_system and actor.has_method("set_inspection_camera"):
		actor.set_inspection_camera(ticket_system.camera_position.global_transform, "ticket_system")
	return true

func _can_interact(actor: Node) -> bool:
	return actor.has_method("is_camera_fixed") and actor.is_camera_fixed()

func _update_destination_label() -> void:
	if is_node_ready():
		destination_label.text = destination
