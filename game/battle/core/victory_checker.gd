class_name VictoryChecker
extends RefCounted

## A side loses when its whole roster (not just its active slot) has
## fainted. Returns true if the battle is over (idempotent — safe to call
## after every action and again at end of turn).
static func check(ctx: BattleContext) -> bool:
	var state := ctx.state
	if state.is_battle_over:
		return true

	var side_a_defeated := state.all_fainted("side_a")
	var side_b_defeated := state.all_fainted("side_b")
	if not side_a_defeated and not side_b_defeated:
		return false

	state.is_battle_over = true
	if side_a_defeated and side_b_defeated:
		state.winner_side = "draw"
	elif side_a_defeated:
		state.winner_side = "side_b"
	else:
		state.winner_side = "side_a"

	ctx.event_bus.emit_event(BattleEndedEvent.new(state.winner_side), state.turn_number)
	return true
