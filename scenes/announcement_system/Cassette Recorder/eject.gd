extends StaticBody3D
class_name RecorderEjectButton

func get_interaction_prompt(_actor: Node) -> String:
	var recorder := get_parent() as CassetteRecorder
	if recorder == null:
		return ""
	if recorder.held_cassette and recorder.cassette_seated:
		return "Left click to eject cassette"
	if not recorder.cassette_ejected:
		return "Left click to eject holder"
	return ""

func activate(_actor: Node) -> bool:
	var recorder := get_parent() as CassetteRecorder
	if recorder == null:
		return false
	var ejected_cassette := recorder.held_cassette if recorder.cassette_seated else null
	recorder.eject()
	if ejected_cassette:
		recorder.cassette_removed.emit(ejected_cassette)
	return true
