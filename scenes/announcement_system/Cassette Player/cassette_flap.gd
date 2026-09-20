extends StaticBody3D
class_name CassetteFlap

func get_interaction_prompt(actor: Node) -> String:
	var parent := get_parent()
	if parent.cassette_ejected and parent.held_cassette and not parent.cassette_seated and not actor.held_item:
		return "Left click to insert cassette"
	if parent.cassette_ejected and not parent.held_cassette:
		return "Left click to close flap"
	return ""

func activate(actor: Node) -> bool:
	var parent := get_parent()
	if parent == null:
		return false
	if parent.cassette_ejected and not parent.held_cassette and actor.held_item:
		return parent.close_flap()
	if actor.held_item:
		return false
	if parent.held_cassette:
		return parent.seat_cassette()
	return parent.close_flap()
