extends Node3D
class_name DepartureBoard


@onready var train_id_label: Label = $SubViewport/BoardUI/VBoxContainer/TrainIDLabel
@onready var train_name_label: Label = $SubViewport/BoardUI/VBoxContainer/TrainNameLabel
@onready var platform_label: Label = $SubViewport/BoardUI/VBoxContainer/PlatformLabel
@onready var status_label: Label = $SubViewport/BoardUI/VBoxContainer/StatusLabel


func display_train(train: Train) -> void:
	train_id_label.text = train.train_id
	train_name_label.text = train.train_name
	platform_label.text = str(train.platform)
	status_label.text = get_status_text(train.status)


func get_status_text(status: int) -> String:
	match status:
		1:
			return "ARRIVING"

		2:
			return "DELAYED"

		3:
			return "CANCELED"
			
		_:
			return "UNKNOWN"
