extends StaticBody3D

@export var fare_price: int = -1
@export var coach_type: String = ""

func set_fare(new_fare: int) -> void:
	fare_price = new_fare

func set_coach(new_coach: String) -> void:
	coach_type = new_coach

func stamp_ticket(ticket: Ticket) -> bool:
	if fare_price < 0 or coach_type.is_empty() or ticket == null:
		return false
	ticket.set_fare(fare_price)
	ticket.set_coach(coach_type)
	return true