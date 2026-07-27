class_name SelfCastSkillOnEntryTraitEffect
extends TraitEffect

## Same idea as SelfCastSkillOnTurnTraitEffect (Random Buff/Oomph/Ping), but
## for the "at the start of the battle" timing (Sudden Ping) -- fires from
## on_monster_entered instead of on_turn_start. A separate small class
## rather than one class branching on a timing flag, matching this
## project's existing convention of dedicated classes per hook timing
## (e.g. ChanceBasedTensionGainTraitEffect vs AllyTensionBuffOnEntryTraitEffect).

@export var skill_data: SkillData
@export var chance: float = 0.3

func on_monster_entered(ctx: BattleContext, owner: MonsterInstance) -> void:
	if skill_data == null or not ctx.rng.chance(chance):
		return
	var skill_lookup := {skill_data.id: skill_data}
	ActionExecutor.execute(ctx, Action.new(owner.instance_id, skill_data.id, owner.instance_id), skill_lookup)
