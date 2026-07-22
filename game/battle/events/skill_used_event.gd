class_name SkillUsedEvent
extends BattleEvent

var actor_instance_id: int
var skill_id: String
var target_instance_id: int
var missed: bool = false
var fizzled: bool = false

func _init(p_actor_instance_id: int, p_skill_id: String, p_target_instance_id: int) -> void:
	actor_instance_id = p_actor_instance_id
	skill_id = p_skill_id
	target_instance_id = p_target_instance_id

func get_event_type() -> String:
	return "skill_used"

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["actor_instance_id"] = actor_instance_id
	d["skill_id"] = skill_id
	d["target_instance_id"] = target_instance_id
	d["missed"] = missed
	d["fizzled"] = fizzled
	return d
