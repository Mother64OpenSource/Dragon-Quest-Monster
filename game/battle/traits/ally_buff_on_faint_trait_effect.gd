class_name AllyBuffOnFaintTraitEffect
extends TraitEffect

## Final Breath: raises every OTHER currently-active, still-living ally's
## stats when the owner faints. Scoped to allies who are already fighting
## alongside the owner at the moment of death (fires before FaintHandler's
## own backfill), not whoever ends up backfilled into the vacated slot(s)
## afterward.

@export var stat_names: Array[String] = ["attack", "defense", "agility", "wisdom"]
@export var stages: int = 1

func on_fainted(ctx: BattleContext, owner: MonsterInstance) -> void:
	for ally in ctx.state.get_active_monsters(owner.side):
		if ally == owner or ally.is_fainted():
			continue
		for stat_name in stat_names:
			var applied_delta := ally.apply_stat_stage(stat_name, stages)
			if applied_delta == 0:
				continue
			ctx.event_bus.emit_event(
				StatChangedEvent.new(ally.instance_id, stat_name, applied_delta, ally.stat_stages.get_stage(stat_name)),
				ctx.state.turn_number
			)
