class_name TurnEndMpDeltaTraitEffect
extends TraitEffect

## Generic per-turn MP regen/drain as a percent of max MP (sign gives the
## direction), applied via the existing on_turn_end hook. Covers Magic
## Regenerator (positive) and Disenchanted (negative) -- the sheet gives no
## exact magnitude for either, so percent_of_max is a deliberately modest,
## documented approximation (see wiki/log.md).

@export var percent_of_max: float = 0.1

func on_turn_end(_ctx: BattleContext, owner: MonsterInstance) -> void:
	var amount := MathUtils.round_half_up(float(owner.species.base_mp) * absf(percent_of_max))
	amount = maxi(1, amount)
	var delta := amount if percent_of_max >= 0.0 else -amount
	owner.current_mp = clampi(owner.current_mp + delta, 0, owner.species.base_mp)
