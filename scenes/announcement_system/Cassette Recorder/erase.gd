extends StaticBody3D
class_name RecorderEraseButton

func get_interaction_prompt(_actor: Node) -> String:
	var recorder := get_parent() as CassetteRecorder
	return "Left click to erase cassette" if recorder and recorder.held_cassette else ""

func activate(_actor: Node) -> bool:
	var recorder := get_parent() as CassetteRecorder
	if recorder == null:
		return false
	return recorder.erase_blank()
