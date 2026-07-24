class_name DesperadoTraitEffect
extends TraitEffect

## Boosted crit chance while this monster's own HP is at or below a
## percentage of its max.

@export var hp_threshold_percent: float = 0.25
@export var multiplier_when_low: float = 2.0

func get_crit_chance_multiplier(owner: MonsterInstance, _category: int) -> float:
	if owner.current_hp <= owner.species.base_hp * hp_threshold_percent:
		return multiplier_when_low
	return 1.0
