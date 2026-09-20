extends Panel

var expression := ""
var stored_value := "0"

@onready var display: LineEdit = $Content/Display

func _ready() -> void:
	display.text = stored_value
	for button in $Content/CalculatorGrid.get_children():
		button.pressed.connect(_on_calculator_button_pressed.bind(button.text))
	for discount in $Content/DiscountRow.get_children():
		discount.pressed.connect(_on_discount_pressed.bind(discount.get_meta("discount_rate")))

func _on_calculator_button_pressed(button_text: String) -> void:
	if button_text == "C":
		expression = ""
		_set_value("0")
		return
	if button_text in ["+", "-", "*", "/"]:
		if expression.is_empty() and display.text.is_valid_float():
			expression = display.text
		if expression.is_empty():
			return
		if expression.right(1) in ["+", "-", "*", "/"]:
			expression = expression.left(-1) + button_text
		else:
			expression += button_text
		_set_value(expression)
		return
	if button_text == "=":
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
		if expression.is_empty() or not expression.right(1).is_valid_int():
			expression += button_text
		else:
			expression += button_text
		_set_value(expression)

func _on_discount_pressed(discount_rate: float) -> void:
	if not expression.is_valid_float():
		return
	expression = str(roundi(float(expression) * (1.0 - discount_rate)))
	_set_value(expression)

func _set_value(value: String) -> void:
	stored_value = value
	display.text = value
