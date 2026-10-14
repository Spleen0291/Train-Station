extends StaticBody3D
class_name ForwardButton

func get_interaction_prompt(_actor: Node) -> String:
	var cassette_player := get_parent() as CassettePlayer
	return "Hold left click to forward" if cassette_player and cassette_player.cassette_seated else ""

func activate(actor: Node) -> bool:
	var cassette_player := get_parent() as CassettePlayer
	return cassette_player != null and cassette_player.forward_button(actor)

func release_hold(actor: Node) -> void:
	actor.stop_cassette_transport()
