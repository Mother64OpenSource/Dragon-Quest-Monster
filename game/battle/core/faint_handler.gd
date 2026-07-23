class_name FaintHandler
extends RefCounted

## Marks a monster fainted exactly once (guarded by
## has_been_processed_as_fainted, since callers may re-check the same
## monster after multiple effects/ticks in the same turn), emits
## MonsterFaintedEvent, and immediately backfills its vacated active
## slot(s) from reserves. M1 has no strategic switch-in choice to make, so
## backfill is deterministic "next non-fainted, non-active team member in
## order" -- and, since a monster can occupy more than one slot, size-aware:
## a fainted 2-slot monster's vacated pair gets filled by whichever fits
## (one 2-slot reserve, or two 1-slot reserves, or partially if nothing
## fits the remainder -- no crash, no forced fit).
static func handle_if_fainted(ctx: BattleContext, monster: MonsterInstance) -> void:
	if monster == null or not monster.is_fainted() or monster.has_been_processed_as_fainted:
		return
	monster.has_been_processed_as_fainted = true
	monster.active_status = null

	ctx.event_bus.emit_event(MonsterFaintedEvent.new(monster.instance_id), ctx.state.turn_number)

	var side := monster.side
	var team := ctx.state.side_a_team if side == "side_a" else ctx.state.side_b_team
	var team_index := team.find(monster)
	if team_index == -1:
		return
	var vacated := ctx.state.get_slots_for_team_index(side, team_index)
	_try_backfill(ctx, side, vacated)

static func _try_backfill(ctx: BattleContext, side: String, vacated_slots: Array[int]) -> void:
	var team := ctx.state.side_a_team if side == "side_a" else ctx.state.side_b_team
	var remaining := vacated_slots.duplicate()
	while not remaining.is_empty():
		var reserve_index := ctx.state.get_first_reserve_index(side, remaining.size())
		if reserve_index == -1:
			break
		var monster := team[reserve_index]
		var size := monster.species.slots
		var slots_to_fill := remaining.slice(0, size)
		for slot in slots_to_fill:
			ctx.state.set_active_at(side, slot, reserve_index)
		monster.slot = slots_to_fill[0]
		ctx.event_bus.emit_event(
			MonsterEnteredEvent.new(monster.instance_id, monster.species.id, side, slots_to_fill[0]),
			ctx.state.turn_number
		)
		remaining = remaining.slice(size, remaining.size())
