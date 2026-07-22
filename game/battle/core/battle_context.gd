class_name BattleContext
extends RefCounted

## Thin bundle passed into every effect/resolver/hook so none of them ever
## reach into globals — also makes unit-testing a single effect trivial
## (construct a fake context around a fake state).

var state: BattleState
var rng: DeterministicRng
var event_bus: BattleEventBus

func _init(p_state: BattleState) -> void:
	state = p_state
	rng = p_state.rng
	event_bus = p_state.event_bus
