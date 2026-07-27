class_name BattleSetup
extends RefCounted

## Sends out each side's initial active monster(s) — team members fill the
## active-slot budget in team order, each claiming as many slots as its own
## species.slots (1-4) costs. Greedy, not optimal bin-packing: a monster that
## doesn't fit the room left is skipped (stays on the bench) and packing
## tries the *next* team member, who might be smaller and fit; it does not
## give up on the rest of the team just because one member didn't fit.
## Emits MonsterEnteredEvent once per monster placed (not once per slot).
static func send_out_initial(ctx: BattleContext, active_slot_count: int = 1) -> void:
	var entered: Array[MonsterInstance] = []
	entered.append_array(_send_out_side(ctx, "side_a", active_slot_count))
	entered.append_array(_send_out_side(ctx, "side_b", active_slot_count))
	# on_monster_entered fires only in this separate pass, AFTER both sides
	# are fully sent out -- a trait affecting "the enemy side" (Scare Stare
	# et al.) needs the opposing side to actually be populated yet, which
	# isn't true partway through _send_out_side("side_a", ...) alone.
	for monster in entered:
		for trait_effect in monster.active_traits:
			trait_effect.on_monster_entered(ctx, monster)

static func _send_out_side(ctx: BattleContext, side: String, active_slot_count: int) -> Array[MonsterInstance]:
	var team := ctx.state.side_a_team if side == "side_a" else ctx.state.side_b_team
	var next_slot := 0
	var entered: Array[MonsterInstance] = []
	for team_index in range(team.size()):
		if next_slot >= active_slot_count:
			break
		var monster := team[team_index]
		var size := monster.species.slots
		if next_slot + size > active_slot_count:
			continue
		for slot in range(next_slot, next_slot + size):
			ctx.state.set_active_at(side, slot, team_index)
		monster.slot = next_slot
		ctx.event_bus.emit_event(
			MonsterEnteredEvent.new(monster.instance_id, monster.species.id, side, next_slot),
			ctx.state.turn_number
		)
		entered.append(monster)
		next_slot += size
	return entered
