extends StaticBody3D
class_name CassetteHolder

func get_interaction_prompt(actor: Node) -> String:
	var parent := get_parent()
	if parent is CassettePlayer:
		if parent.cassette_ejected and actor.held_item and not parent.held_cassette:
			return "Left click to insert cassette"
		return ""
	if parent is CassetteRecorder:
		if parent.cassette_ejected and actor.held_item and not parent.held_cassette:
			return "Left click to insert cassette"
		return ""
	return ""

func activate(actor: Node) -> bool:
	var parent := get_parent()
	if parent is CassettePlayer:
		if parent.cassette_ejected:
			return parent.insert_from_actor(actor)
		return false
	if parent is CassetteRecorder:
		if parent.cassette_ejected:
			return parent.insert_from_actor(actor)
		return false
	return false
