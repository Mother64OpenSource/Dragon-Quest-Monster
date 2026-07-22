class_name FaintHandler
extends RefCounted

## Marks a monster fainted exactly once (guarded by
## has_been_processed_as_fainted, since callers may re-check the same
## monster after multiple effects/ticks in the same turn), emits
## MonsterFaintedEvent, and immediately backfills its vacated active slot
## from reserves. M1 has no strategic switch-in choice to make, so backfill
## is deterministic "next non-fainted, non-active team member in order."
static func handle_if_fainted(ctx: BattleContext, monster: MonsterInstance) -> void:
	if monster == null or not monster.is_fainted() or monster.has_been_processed_as_fainted:
		return
	monster.has_been_processed_as_fainted = true
	monster.active_status = null

	ctx.event_bus.emit_event(MonsterFaintedEvent.new(monster.instance_id), ctx.state.turn_number)
	_try_backfill(ctx, monster.side, monster.slot)

static func _try_backfill(ctx: BattleContext, side: String, slot: int) -> void:
	var reserve_index := ctx.state.get_first_reserve_index(side)
	if reserve_index == -1:
		return
	ctx.state.set_active_at(side, slot, reserve_index)
	var monster := ctx.state.get_monster_at(side, slot)
	if monster != null:
		monster.slot = slot
		ctx.event_bus.emit_event(
			MonsterEnteredEvent.new(monster.instance_id, monster.species.id, side, slot),
			ctx.state.turn_number
		)
