class_name StartOfTurnProcessor
extends RefCounted

## Fires on_turn_start trait hooks, in fixed canonical side/slot order,
## before any action for the round is collected -- mirrors
## EndOfTurnProcessor exactly, just at the other end of the turn. Used for
## per-turn tension buildup (Sudden Tension, Wrath of the Stars).
static func process(ctx: BattleContext) -> void:
	for side in ["side_a", "side_b"]:
		for monster in ctx.state.get_active_monsters(side):
			if monster.is_fainted():
				continue
			for trait_effect in monster.active_traits:
				trait_effect.on_turn_start(ctx, monster)
