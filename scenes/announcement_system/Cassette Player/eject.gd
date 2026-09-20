extends StaticBody3D
class_name EjectButton

func get_interaction_prompt(actor: Node) -> String:
	var cassette_player := get_parent() as CassettePlayer
	if cassette_player == null:
		return ""
	if cassette_player.held_cassette and cassette_player.cassette_seated:
		return "Left click to eject cassette"
	if not cassette_player.cassette_ejected:
		return "Left click to eject holder"
	return ""

func activate(actor: Node) -> bool:
	var cassette_player := get_parent() as CassettePlayer
	if cassette_player == null:
		return false
	var ejected_cassette := cassette_player.held_cassette if cassette_player.cassette_seated else null
	cassette_player.eject()
	if ejected_cassette:
		cassette_player.cassette_removed.emit(ejected_cassette)
	return true
