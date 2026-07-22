class_name StatusInstance
extends RefCounted

var status_data: StatusData
var remaining_turns: int

func _init(p_status_data: StatusData) -> void:
	status_data = p_status_data
	remaining_turns = p_status_data.duration_turns
