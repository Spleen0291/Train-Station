extends StaticBody3D
class_name StopButton

func get_interaction_prompt(_actor: Node) -> String:
	var cassette_player := get_parent() as CassettePlayer
	return "Left click to stop" if cassette_player and cassette_player.cassette_seated else ""

func activate(actor: Node) -> bool:
	var cassette_player := get_parent() as CassettePlayer
	return cassette_player != null and cassette_player.stop_button(actor)
