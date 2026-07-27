class_name StackingStatBuffOnTurnTraitEffect
extends TraitEffect

## Hidden Power: "Increased Attack, Defense, Agility, Wisdom each round" --
## raises all four StatStages-tracked stats by one stage at the start of
## every one of the owner's own turns, self only. No explicit cap is
## mentioned in the source description, but none is needed: StatStages'
## own symmetric +/-6-stage ceiling already bounds this safely regardless
## of how many rounds a battle runs.

const STAT_NAMES: Array[String] = ["attack", "defense", "agility", "wisdom"]

@export var stages: int = 1

func on_turn_start(ctx: BattleContext, owner: MonsterInstance) -> void:
	if owner.is_fainted():
		return
	for stat_name in STAT_NAMES:
		var applied_delta := owner.apply_stat_stage(stat_name, stages)
		if applied_delta == 0:
			continue
		ctx.event_bus.emit_event(
			StatChangedEvent.new(owner.instance_id, stat_name, applied_delta, owner.stat_stages.get_stage(stat_name)),
			ctx.state.turn_number
		)
