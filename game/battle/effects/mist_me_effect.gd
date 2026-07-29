class_name MistMeEffect
extends SkillEffect

## "Take no damage once by hiding within mist. Has a chance of failure."
## The chance is rolled once, right here at cast time (matching "has a
## chance of failure" -- the mist either forms or it doesn't), not
## re-rolled against each incoming hit. An @export, not a hardcoded const,
## same reason as CounterAttackTraitEffect.counter_chance et al. -- lets a
## test deterministically force the 0.0/1.0 short-circuit case (see
## DeterministicRng.chance()) rather than depending on RNG sequence luck.
## No sourced real number exists for the default -- a documented
## placeholder, same honesty convention as this project's other invented
## constants (see DamageEffect's own).
@export var success_chance: float = 0.5

func apply(ctx: BattleContext, user: MonsterInstance, _target: MonsterInstance) -> void:
	if ctx.rng.chance(success_chance):
		user.mist_me_active = true
