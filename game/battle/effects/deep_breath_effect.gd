class_name DeepBreathEffect
extends SkillEffect

## "Increase damage of breath attacks that you next use by taking a deep
## breath." Sets a one-turn charge (see MonsterInstance.deep_breath_charged's
## own doc comment); the actual damage boost lives in DamageEffect.apply(),
## since that's the only place a concrete Breath-type damage roll exists.
func apply(_ctx: BattleContext, user: MonsterInstance, _target: MonsterInstance) -> void:
	user.deep_breath_charged = true
