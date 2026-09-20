extends StaticBody3D
signal served(npc: StaticBody3D)

var destination: String = ""
var coach_type: String = ""
var category: String = ""
var request_board: TicketRequestBoard

const REQUEST_BOARD_SCENE := preload("res://scenes/ticket_system/ticket_request_board.tscn")

func setup(requested_destination: String, requested_coach_type: String, requested_category: String) -> void:
	destination = requested_destination
	coach_type = requested_coach_type
	category = requested_category
	_apply_category_color()
	request_board = REQUEST_BOARD_SCENE.instantiate() as TicketRequestBoard
	request_board.destination = destination
	request_board.coach_type = coach_type
	request_board.game_manager = null
	add_child(request_board)
	request_board.visible = true
	request_board.position = Vector3(1.5, 1.5, 0)
	request_board.rotation = Vector3(0, PI / 2.0, 0)
	request_board.scale = Vector3.ONE * 0.75

func _apply_category_color() -> void:
	var category_colors := {
		"child": Color("#66c56c"),
		"male": Color("#4da6ff"),
		"female": Color("#e58ac5"),
		"old": Color("#d9a441")
	}
	var color: Color = category_colors.get(category, Color("#b8c0cc"))
	for mesh_node in [$body, $head]:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		mesh_node.material_override = material

func _get_fare_discount() -> float:
	match category:
		"child":
			return 0.50
		"male":
			return 0.0
		"female":
			return 0.25
		"old":
			return 0.40
		_:
			return 0.0

func accept_ticket(ticket: Ticket) -> bool:
	if not ticket:
		return false
	var base_fare : int = ScheduleDatabase.get_fare_to_destination(ticket.to_station)
	var expected_fare := roundi(float(base_fare) * (1.0 - _get_fare_discount()))
	var is_correct := ticket.to_station.to_lower() == destination.to_lower()
	is_correct = is_correct and ticket.coach_type.to_lower() == coach_type.to_lower()
	is_correct = is_correct and ticket.fare_price >= 0 and ticket.fare_price == expected_fare
	served.emit(self)
	queue_free()
	return is_correct
