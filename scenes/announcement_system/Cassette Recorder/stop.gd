extends StaticBody3D
class_name RecorderStopButton

func get_interaction_prompt(_actor: Node) -> String:
	var recorder := get_parent() as CassetteRecorder
	return "Left click to stop" if recorder and (recorder.is_copying or recorder.is_erasing or recorder.button_seek_direction != 0) else ""

func activate(_actor: Node) -> bool:
	var recorder := get_parent() as CassetteRecorder
	if recorder == null:
		return false
	recorder.stop_copying()
	return true
