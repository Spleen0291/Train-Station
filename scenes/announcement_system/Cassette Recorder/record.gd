extends StaticBody3D
class_name RecorderRecordButton

func get_interaction_prompt(_actor: Node) -> String:
	var recorder := get_parent() as CassetteRecorder
	if recorder == null or recorder.held_cassette == null or recorder.is_erasing:
		return ""
	return "Left click to stop recording" if recorder.is_copying else "Left click to record cassette"

func activate(actor: Node) -> bool:
	var recorder := get_parent() as CassetteRecorder
	if recorder == null:
		return false
	return recorder.run_copy(actor)
