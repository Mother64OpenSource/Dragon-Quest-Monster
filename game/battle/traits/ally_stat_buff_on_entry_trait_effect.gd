class_name AllyStatBuffOnEntryTraitEffect
extends TraitEffect

## Generic "raises the whole party's stat at the start of the battle" trait
## (Sudden Buff, Sudden Oomph, Sudden Accelerate, Random Accelerate).
## Includes the owner itself -- "party" means everyone, not just allies.
## stages maps directly onto StatStages' own multiplier curve where a real
## percentage is given (+1 stage = 1.5x = "+50%", +2 = 2.0x = "doubles"),
## no approximation needed for those two specific cases.

@export var stat_name: String = "attack"
@export var stages: int = 1
@export var chance: float = 1.0

func on_monster_entered(ctx: BattleContext, owner: MonsterInstance) -> void:
	if not ctx.rng.chance(chance):
		return
	for ally in ctx.state.get_active_monsters(owner.side):
		if ally.is_fainted():
			continue
		var applied_delta := ally.apply_stat_stage(stat_name, stages)
		if applied_delta == 0:
			continue
		ctx.event_bus.emit_event(
			StatChangedEvent.new(ally.instance_id, stat_name, applied_delta, ally.stat_stages.get_stage(stat_name)),
			ctx.state.turn_number
		)
