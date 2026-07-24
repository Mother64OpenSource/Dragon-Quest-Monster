class_name DefendEvent
extends BattleEvent

var actor_instance_id: int

func _init(p_actor_instance_id: int) -> void:
	actor_instance_id = p_actor_instance_id

func get_event_type() -> String:
	return "defend"

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["actor_instance_id"] = actor_instance_id
	return d
