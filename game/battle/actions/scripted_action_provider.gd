class_name ScriptedActionProvider
extends ActionProvider

## M1's trivial stand-in "AI": returns actions from a pre-scripted queue keyed
## by instance_id (a fainted monster's reserve replacement gets its own queue
## entry under its own instance_id).
var _queues: Dictionary = {}

func set_queue(instance_id: int, actions: Array[Action]) -> void:
	_queues[instance_id] = actions.duplicate()

func get_action(state: BattleState, side: String, slot: int) -> Action:
	var monster := state.get_monster_at(side, slot)
	if monster == null:
		push_error("No monster at side=%s slot=%d" % [side, slot])
		return null
	var queue: Array = _queues.get(monster.instance_id, [])
	if queue.is_empty():
		push_error("ScriptedActionProvider has no queued action for instance_id=%d" % monster.instance_id)
		return null
	return queue.pop_front()
