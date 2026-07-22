class_name BattleEventBus
extends RefCounted

## One instance per battle (never an autoload) — this is the render/logic
## decoupling seam. UI, headless test listeners, or a future network
## broadcaster all just connect to event_emitted; none of them can feed
## anything back into the engine through this bus.

signal event_emitted(event: BattleEvent)

var _log: Array[BattleEvent] = []
var _next_sequence_id: int = 0

func emit_event(event: BattleEvent, turn_number: int) -> void:
	event.turn_number = turn_number
	event.sequence_id = _next_sequence_id
	_next_sequence_id += 1
	_log.append(event)
	event_emitted.emit(event)

func get_log() -> Array[BattleEvent]:
	return _log
