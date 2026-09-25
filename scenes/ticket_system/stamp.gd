extends StaticBody3D

@export var fare_price: int = -1
@export var coach_type: String = ""

func get_interaction_prompt(actor: Node) -> String:
	if actor.held_item is Ticket:
		return "Left click to print fare"
	return "Hold a ticket and left click to print fare"

func activate(actor: Node) -> bool:
	if not actor.held_item is Ticket:
		return false
	var calculator := get_node_or_null("../Calculator") as TicketCalculator
	if calculator == null:
		return false
	var calculated_fare := calculator.get_fare_value()
	if calculated_fare < 0:
		return false
	fare_price = calculated_fare
	print("Fare: ", calculated_fare)
	(actor.held_item as Ticket).set_fare(calculated_fare)
	return true

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