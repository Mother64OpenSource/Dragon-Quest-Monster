class_name StatusTickEvent
extends BattleEvent

var target_instance_id: int
var status_id: String
var damage: int
var resulting_hp: int
var expired: bool

func _init(p_target_instance_id: int, p_status_id: String, p_damage: int, p_resulting_hp: int, p_expired: bool) -> void:
	target_instance_id = p_target_instance_id
	status_id = p_status_id
	damage = p_damage
	resulting_hp = p_resulting_hp
	expired = p_expired

func get_event_type() -> String:
	return "status_tick"

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["target_instance_id"] = target_instance_id
	d["status_id"] = status_id
	d["damage"] = damage
	d["resulting_hp"] = resulting_hp
	d["expired"] = expired
	return d
