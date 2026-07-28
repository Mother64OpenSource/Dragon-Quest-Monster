class_name TauntEffect
extends SkillEffect

## Selflessness et al.: "Takes damage instead of ally." Sets the user's
## is_taunting flag -- the actual redirect (ActionExecutor.execute()) and
## the "significantly increases damage taken" half
## (DamageEffect._run_damage_hooks(), TAUNT_DAMAGE_MULTIPLIER) both live
## elsewhere, since neither has a concrete target/damage number available
## at the point this effect itself applies. Always self-targeted (see
## selflessness.json's target_type), so `target` is unused here -- kept as
## a parameter only to match every other SkillEffect.apply() signature.
func apply(_ctx: BattleContext, user: MonsterInstance, _target: MonsterInstance) -> void:
	user.is_taunting = true
