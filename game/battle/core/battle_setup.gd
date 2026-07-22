class_name BattleSetup
extends RefCounted

## Sends out each side's initial active monster(s) — the first N team
## members fill the N active slots, matching typical team-order semantics
## the later team builder will produce. Emits MonsterEnteredEvent per slot.
static func send_out_initial(ctx: BattleContext, active_slot_count: int = 1) -> void:
	_send_out_side(ctx, "side_a", active_slot_count)
	_send_out_side(ctx, "side_b", active_slot_count)

static func _send_out_side(ctx: BattleContext, side: String, active_slot_count: int) -> void:
	for slot in range(active_slot_count):
		ctx.state.set_active_at(side, slot, slot)
		var monster := ctx.state.get_monster_at(side, slot)
		if monster != null:
			monster.slot = slot
			ctx.event_bus.emit_event(
				MonsterEnteredEvent.new(monster.instance_id, monster.species.id, side, slot),
				ctx.state.turn_number
			)
