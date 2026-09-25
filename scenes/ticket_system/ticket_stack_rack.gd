extends Node3D
class_name TicketStackRack

const SELECTED_Z_OFFSET := -0.3

var selected_destination := ""

func is_destination_selected(destination: String) -> bool:
	return selected_destination == destination

func select_destination(destination: String) -> void:
	selected_destination = destination
	for child in get_children():
		if child is TicketStack:
			var stack := child as TicketStack
			stack.position.z = stack.base_position.z
			if stack.destination == selected_destination:
				stack.position.z += SELECTED_Z_OFFSET
				stack.destination_label.visible = false
			else:
				stack.destination_label.visible = stack.destination_label_enabled

func clear_selection() -> void:
	selected_destination = ""
	for child in get_children():
		if child is TicketStack:
			var stack := child as TicketStack
			stack.position.z = stack.base_position.z
			stack.destination_label.visible = stack.destination_label_enabled
