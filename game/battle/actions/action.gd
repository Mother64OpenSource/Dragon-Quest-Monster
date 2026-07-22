class_name Action
extends RefCounted

## Transient per-turn submitted intent. Referenced by instance_id, not object
## reference, and shaped with to_dict()/from_dict() as the replay-log seed —
## nothing persists it to disk yet, but the shape matters for later.

enum Type { SKILL }

var actor_instance_id: int
var action_type: Type = Type.SKILL
var skill_id: String = ""
var target_instance_id: int = -1
var submission_index: int = -1

func _init(p_actor_instance_id: int, p_skill_id: String, p_target_instance_id: int) -> void:
	actor_instance_id = p_actor_instance_id
	skill_id = p_skill_id
	target_instance_id = p_target_instance_id

func to_dict() -> Dictionary:
	return {
		"actor_instance_id": actor_instance_id,
		"action_type": "skill",
		"skill_id": skill_id,
		"target_instance_id": target_instance_id,
		"submission_index": submission_index,
	}

static func from_dict(d: Dictionary) -> Action:
	var action := Action.new(
		int(d.get("actor_instance_id", -1)),
		d.get("skill_id", ""),
		int(d.get("target_instance_id", -1))
	)
	action.submission_index = int(d.get("submission_index", -1))
	return action
