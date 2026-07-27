class_name TensionBurnMultiplierTraitEffect
extends TraitEffect

## Dust of the Clan: "Trait holder and same family allies have chance of
## 2x Tension Burn." The "same family allies" clause collapses to
## self-only, the same simplification every ally-scoped support effect in
## this project already uses (this engine has no ally-targeting at all).
## No sourced real chance exists -- a documented placeholder, same
## convention as every other invented numeric constant in this project.

@export var chance: float = 0.5
@export var multiplier: float = 2.0

func get_tension_burn_multiplier(ctx: BattleContext) -> float:
	return multiplier if ctx.rng.chance(chance) else 1.0
