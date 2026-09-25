extends Node3D
class_name TicketCalculator

var expression := ""
var stored_value := "0"

@onready var display: Label = $SubViewport/Control/"Calculator Text"

func _ready() -> void:
	display.text = stored_value

func get_interaction_prompt(actor: Node) -> String:
	if actor.has_method("is_camera_fixed") and actor.is_camera_fixed():
		return "Left click to use calculator"
	return ""

func activate(actor: Node) -> bool:
	if not actor.has_method("is_camera_fixed") or not actor.is_camera_fixed():
		return false
	return true

func get_fare_value() -> int:
	if not display.text.is_valid_float():
		return -1
	return roundi(float(display.text))

func press_button(button_text: String) -> void:
	if button_text == "Clear":
		expression = ""
		_set_value("0")
		return
	if button_text in ["add", "subtract", "multiply", "divide"]:
		var operator : String = {"add": "+", "subtract": "-", "multiply": "*", "divide": "/"}[button_text]
		if expression.is_empty() and display.text.is_valid_float():
			expression = display.text
		if expression.is_empty():
			return
		if expression.right(1) in ["+", "-", "*", "/"]:
			expression = expression.left(-1) + operator
		else:
			expression += operator
		_set_value(expression)
		return
	if button_text == "Equals":
		if expression.is_empty() or expression.right(1) in ["+", "-", "*", "/"]:
			return
		var calculator_expression := Expression.new()
		if calculator_expression.parse(expression) != OK:
			_set_value("Error")
			expression = ""
			return
		var result = calculator_expression.execute()
		if calculator_expression.has_execute_failed() or not (result is float or result is int):
			_set_value("Error")
			expression = ""
			return
		expression = str(result)
		_set_value(expression)
		return
	if button_text.is_valid_int():
		expression += button_text
		_set_value(expression)

func _set_value(value: String) -> void:
	stored_value = value
	display.text = value
