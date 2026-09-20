extends StaticBody3D
class_name RecorderRewindButton

func get_interaction_prompt(_actor: Node) -> String:
	var recorder := get_parent() as CassetteRecorder
	return "Left click to rewind" if recorder and recorder.held_cassette else ""

func activate(_actor: Node) -> bool:
	var recorder := get_parent() as CassetteRecorder
	return recorder != null and recorder.rewind_button(_actor)
