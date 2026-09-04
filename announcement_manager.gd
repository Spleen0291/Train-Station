extends Node
class_name AnnouncementManager

@export var game_manager: GameManager
@onready var attention_call: String = "Passengers, Please pay Attention."
@onready var trian_number: String = "Train Number:"
@onready var delay: String = "has been delayed."
@onready var cancel: String = "has been canceled."
@onready var arrival: String = "will be arriving on"
@onready var apology: String = "Sorry for any inconvenience caused."

signal correct_announcement

var current_train: Train
var task_active: bool = false

func check_announcement(phrase: String) -> bool:
	var current_id = game_manager.current_train.train_id
	var current_name = game_manager.current_train.train_name
	var current_platform: String = "platform" + str(game_manager.current_train.platform)
	var current_status: String = ""
	var ending: String = ""
	
	if game_manager.current_train.status == 1:
		current_status = arrival
		ending = current_status + " " + current_platform
		
	if game_manager.current_train.status == 2:
		current_status = delay
		ending = current_status + apology
		
	if game_manager.current_train.status == 3:
		current_status = cancel
		ending = current_status + apology
		
	var correct_announcement: String = attention_call + trian_number + current_id + current_name + ending
	# Normalize both strings (case-insensitive, whitespace- and punctuation-insensitive)
	var norm_input := _normalize(phrase)
	var norm_correct := _normalize(correct_announcement)
	return norm_input == norm_correct


func _normalize(s: String) -> String:
	var out := ""
	var lower := s.to_lower()
	for ch in lower:
		# keep only ASCII letters and digits
		if ch >= "a" and ch <= "z":
			out += ch
		elif ch >= "0" and ch <= "9":
			out += ch
	# removes spaces, punctuation, and makes comparison case-insensitive
	return out
