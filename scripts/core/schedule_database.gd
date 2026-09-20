extends Node

const TRAINS_JSON_PATH := "res://data/trains.json"
const SCHEDULE_JSON_PATH := "res://data/days.json"
const TICKET_COSTS_JSON_PATH := "res://data/ticket_costs.json"
const STARTING_STATION := "Kaalnagar"

var _trains_data: Dictionary = {}   
var _days_data: Dictionary = {}
var _ticket_costs: Dictionary = {}
var active_train: Train

signal active_train_changed(train: Train)

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

func _station_key(station: String) -> String:
	return station.strip_edges().to_lower()

func _load_ticket_costs(path: String) -> void:
	var parsed := _load_json_dict(path)
	for connection in parsed.get("connections", []):
		var from_station: String = _station_key(connection.get("from", ""))
		var to_station: String = _station_key(connection.get("to", ""))
		var cost: int = connection.get("cost", -1)
		_ticket_costs[from_station + "|" + to_station] = cost
		_ticket_costs[to_station + "|" + from_station] = cost

func _build_train(train_data: Dictionary, train_info: Dictionary) -> Train:
	var t := Train.new()

	t.train_id = train_data.get("train_id")
	t.train_name = train_data.get("train_name")
	t.destinations.assign(train_data.get("destinations", []))
	t.platform = train_info.get("platform")
	t.status = train_info.get("status")
	return t
	
func get_trains(day_number: int) -> Array[Train]:
	day_trains.clear()

	for train_info in _days_data[day_number]:
		var id: String = train_info.get("train_id")
		day_trains.append(_build_train(_trains_data[id], train_info))
		
	return day_trains

func get_unique_destinations() -> Array[String]:
	var destinations: Array[String] = []
	for train_data in _trains_data.values():
		for destination in train_data.get("destinations", []):
			if not destinations.has(destination):
				destinations.append(destination)
	return destinations

func set_active_train(train: Train) -> void:
	active_train = train
	active_train_changed.emit(train)

func get_route_to_destination(destination: String) -> Array[String]:
	if active_train == null:
		return []

	var route: Array[String] = [STARTING_STATION]
	for station in active_train.destinations:
		route.append(station)
		if _station_key(station) == _station_key(destination):
			return route
	return []

func get_fare_to_destination(destination: String) -> int:
	var route := get_route_to_destination(destination)
	if route.is_empty():
		return -1

	var total := 0
	for index in range(route.size() - 1):
		var connection_key := _station_key(route[index]) + "|" + _station_key(route[index + 1])
		if not _ticket_costs.has(connection_key):
			return -1
		total += _ticket_costs[connection_key]
	return total
	
func _ready() -> void:
	_load_trains(TRAINS_JSON_PATH)
	_load_days(SCHEDULE_JSON_PATH)
	_load_ticket_costs(TICKET_COSTS_JSON_PATH)
