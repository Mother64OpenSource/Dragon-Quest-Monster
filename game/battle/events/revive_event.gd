class_name ReviveEvent
extends BattleEvent

var instance_id: int
var resulting_hp: int

func _init(p_instance_id: int, p_resulting_hp: int) -> void:
	instance_id = p_instance_id
	resulting_hp = p_resulting_hp

func get_event_type() -> String:
	return "revive"

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["instance_id"] = instance_id
	d["resulting_hp"] = resulting_hp
	return d
