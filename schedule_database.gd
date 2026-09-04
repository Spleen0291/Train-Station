extends Node

const TRAINS_JSON_PATH := "res://data/trains.json"
const SCHEDULE_JSON_PATH := "res://data/days.json"

var _trains_data: Dictionary = {}   
var _days_data: Dictionary = {}

var day_trains: Array[Train] = []

func _load_json_dict(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	return parsed	

func _load_trains(path: String) -> void:
	var parsed := _load_json_dict(path)
	for train in parsed.get("trains", []):
		_trains_data[train.get("train_id")] = train


func _load_days(path: String) -> void:
	var parsed := _load_json_dict(path)
	for day in parsed.get("days", []):
		var day_number: int = day.get("day_num")
		_days_data[day_number] = day.get("trains")

func _build_train(train_data: Dictionary, train_info: Dictionary) -> Train:
	var t := Train.new()

	t.train_id = train_data.get("train_id")
	t.train_name = train_data.get("train_name")
	t.platform = train_info.get("platform")
	t.status = train_info.get("status")
	return t
	
func get_trains(day_number: int) -> Array[Train]:
	day_trains.clear()

	for train_info in _days_data[day_number]:
		var id: String = train_info.get("train_id")
		day_trains.append(_build_train(_trains_data[id], train_info))
		
	return day_trains
	
func _ready() -> void:
	_load_trains(TRAINS_JSON_PATH)
	_load_days(SCHEDULE_JSON_PATH)
