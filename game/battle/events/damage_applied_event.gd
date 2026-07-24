class_name DamageAppliedEvent
extends BattleEvent

var source_instance_id: int
var target_instance_id: int
var amount: int
var resulting_hp: int
var is_critical: bool = false
## True when a trait hook (dodge/block) brought otherwise-positive damage
## down to exactly 0 -- narrated as "dodged," distinct from a damage-
## reduction trait leaving a small but nonzero amount.
var was_negated: bool = false

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
	d["is_critical"] = is_critical
	d["was_negated"] = was_negated
	return d
