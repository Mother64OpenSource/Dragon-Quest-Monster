class_name StatusAppliedEvent
extends BattleEvent

var target_instance_id: int
var status_id: String

func _init(p_target_instance_id: int, p_status_id: String) -> void:
	target_instance_id = p_target_instance_id
	status_id = p_status_id

func get_event_type() -> String:
	return "status_applied"

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["target_instance_id"] = target_instance_id
	d["status_id"] = status_id
	return d
