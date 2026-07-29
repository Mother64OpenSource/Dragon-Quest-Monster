class_name CounterStanceEffect
extends SkillEffect

## Counter/Counter Slash/Counter Attack/Counter Breath/Counter Dance/
## Counter Magic: a one-turn stance (lasts until the caster's own next
## action, see ActionExecutor.execute()) that retaliates against any
## matching-category attack taken before then -- the skill-triggered
## counterpart to CounterAttackTraitEffect (a permanent, trait-driven
## version of the same idea; the actual retaliation math is shared, see
## DamageEffect._maybe_counter_attack()). One generic class reused for
## every "Counter X" skill, parameterized by which SkillData.skill_type
## values it answers -- do not write a bespoke class per skill name.
@export var allowed_skill_types: Array[String] = []

func apply(_ctx: BattleContext, user: MonsterInstance, _target: MonsterInstance) -> void:
	user.countering_skill_types = allowed_skill_types.duplicate()
