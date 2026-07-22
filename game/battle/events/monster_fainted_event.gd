class_name MonsterFaintedEvent
extends BattleEvent

var instance_id: int

func _init(p_instance_id: int) -> void:
	instance_id = p_instance_id

func get_event_type() -> String:
	return "monster_fainted"

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["instance_id"] = instance_id
	return d
