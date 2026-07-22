class_name BattleEvent
extends RefCounted

## Base for every battle event. sequence_id/turn_number are stamped by
## BattleEventBus.emit_event(), not by the emitting code, so ordering is
## always consistent with the log. to_dict() is the replay-log skeleton —
## nothing persists it to disk yet, but the shape is load-bearing later.

var sequence_id: int = -1
var turn_number: int = 0

func get_event_type() -> String:
	return "battle_event"

func to_dict() -> Dictionary:
	return {
		"event_type": get_event_type(),
		"sequence_id": sequence_id,
		"turn_number": turn_number,
	}
