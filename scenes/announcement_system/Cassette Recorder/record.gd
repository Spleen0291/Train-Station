extends StaticBody3D
class_name RecorderRecordButton

func get_interaction_prompt(_actor: Node) -> String:
	var recorder := get_parent() as CassetteRecorder
	return "Left click to record cassette" if recorder and recorder.held_cassette and not recorder.is_copying and not recorder.is_erasing else ""

func activate(actor: Node) -> bool:
	var recorder := get_parent() as CassetteRecorder
	if recorder == null:
		return false
	return recorder.run_copy(actor)
