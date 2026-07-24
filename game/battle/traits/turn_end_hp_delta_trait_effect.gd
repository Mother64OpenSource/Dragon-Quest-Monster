class_name TurnEndHpDeltaTraitEffect
extends TraitEffect

## Generic per-turn HP regen/drain as a percent of max HP (sign gives the
## direction), applied via the existing on_turn_end hook. Covers traits
## like Steady Recovery ("recovers a little HP each time it acts") -- the
## sheet gives no exact magnitude for these, so percent_of_max is a
## deliberately modest, documented approximation (see wiki/log.md).

@export var percent_of_max: float = 0.05

func on_turn_end(_ctx: BattleContext, owner: MonsterInstance) -> void:
	var amount := MathUtils.round_half_up(float(owner.species.base_hp) * absf(percent_of_max))
	amount = maxi(1, amount)
	if percent_of_max >= 0.0:
		owner.heal(amount)
	else:
		owner.take_damage(amount)
