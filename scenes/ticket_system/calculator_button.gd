extends StaticBody3D
class_name TicketCalculatorButton

func get_interaction_prompt(actor: Node) -> String:
	var calculator := get_parent()
	if calculator == null or not calculator.has_method("get_interaction_prompt"):
		return ""
	if calculator.get_interaction_prompt(actor) == "":
		return ""
	return "Left click to press " + _get_button_character()

func activate(actor: Node) -> bool:
	var calculator := get_parent()
	if calculator == null or not calculator.has_method("activate") or not calculator.activate(actor):
		return false
	calculator.press_button(name)
	return true

func _get_button_character() -> String:
	return {
		"add": "+",
		"subtract": "-",
		"multiply": "*",
		"divide": "/",
		"Clear": "C",
		"Equals": "="
	}.get(name, name)
