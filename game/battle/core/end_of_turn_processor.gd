class_name EndOfTurnProcessor
extends RefCounted

## Status ticks + on_turn_end trait hooks, in fixed canonical side/slot order
## (side_a then side_b, slot 0 upward) — never based on iteration order that
## isn't already canonical.
static func process(ctx: BattleContext) -> void:
	for side in ["side_a", "side_b"]:
		for monster in ctx.state.get_active_monsters(side):
			if monster.is_fainted():
				continue
			StatusResolver.tick(ctx, monster)
			FaintHandler.handle_if_fainted(ctx, monster)

	for side in ["side_a", "side_b"]:
		for monster in ctx.state.get_active_monsters(side):
			if monster.is_fainted():
				continue
			for trait_effect in monster.active_traits:
				trait_effect.on_turn_end(ctx, monster)
