class_name MpDrainEvent
extends BattleEvent

var source_instance_id: int
var target_instance_id: int
var amount: int

func _init(p_source_instance_id: int, p_target_instance_id: int, p_amount: int) -> void:
	source_instance_id = p_source_instance_id
	target_instance_id = p_target_instance_id
	amount = p_amount

func get_event_type() -> String:
	return "mp_drain"

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["source_instance_id"] = source_instance_id
	d["target_instance_id"] = target_instance_id
	d["amount"] = amount
	return d
