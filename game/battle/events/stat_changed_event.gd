class_name StatChangedEvent
extends BattleEvent

var target_instance_id: int
var stat_name: String
var delta_applied: int
var new_stage: int

func _init(p_target_instance_id: int, p_stat_name: String, p_delta_applied: int, p_new_stage: int) -> void:
	target_instance_id = p_target_instance_id
	stat_name = p_stat_name
	delta_applied = p_delta_applied
	new_stage = p_new_stage

func get_event_type() -> String:
	return "stat_changed"

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["target_instance_id"] = target_instance_id
	d["stat_name"] = stat_name
	d["delta_applied"] = delta_applied
	d["new_stage"] = new_stage
	return d
