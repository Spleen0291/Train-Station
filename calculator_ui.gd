extends Panel

var first_value: float = 0.0
var pending_operator := ""
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
		first_value = 0.0
		pending_operator = ""
		_set_value("0")
		return
	if button_text in ["+", "-", "*", "/"]:
		if display.text.is_valid_float():
			first_value = float(display.text)
			pending_operator = button_text
		_set_value("0")
		return
	if button_text == "=":
		if not display.text.is_valid_float() or pending_operator.is_empty():
			return
		var second_value := float(display.text)
		var result := 0.0
		match pending_operator:
			"+":
				result = first_value + second_value
			"-":
				result = first_value - second_value
			"*":
				result = first_value * second_value
			"/":
				if is_zero_approx(second_value):
					_set_value("Error")
					pending_operator = ""
					return
				result = first_value / second_value
		_set_value(str(result))
		pending_operator = ""
		return
	if button_text.is_valid_int():
		if display.text == "0" or not display.text.is_valid_float():
			_set_value(button_text)
		else:
			_set_value(display.text + button_text)

func _on_discount_pressed(discount_rate: float) -> void:
	if not display.text.is_valid_float():
		return
	_set_value(str(roundi(float(display.text) * (1.0 - discount_rate))))

func _set_value(value: String) -> void:
	stored_value = value
	display.text = value
