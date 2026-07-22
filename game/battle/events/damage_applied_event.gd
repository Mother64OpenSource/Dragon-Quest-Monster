class_name DamageAppliedEvent
extends BattleEvent

var source_instance_id: int
var target_instance_id: int
var amount: int
var resulting_hp: int

func _init(p_source_instance_id: int, p_target_instance_id: int, p_amount: int, p_resulting_hp: int) -> void:
	source_instance_id = p_source_instance_id
	target_instance_id = p_target_instance_id
	amount = p_amount
	resulting_hp = p_resulting_hp

func get_event_type() -> String:
	return "damage_applied"

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["source_instance_id"] = source_instance_id
	d["target_instance_id"] = target_instance_id
	d["amount"] = amount
	d["resulting_hp"] = resulting_hp
	return d
