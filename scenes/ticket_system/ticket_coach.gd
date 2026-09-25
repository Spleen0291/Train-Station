extends StaticBody3D
class_name TicketCoach

@export var coach_type := ""

func get_interaction_prompt(actor: Node) -> String:
	var stack := get_parent() as TicketStack
	if stack == null:
		return ""
	return stack.get_interaction_prompt(actor, coach_type)

func activate(actor: Node) -> bool:
	var stack := get_parent() as TicketStack
	if stack == null:
		return false
	return stack.activate(actor, coach_type, global_position)
