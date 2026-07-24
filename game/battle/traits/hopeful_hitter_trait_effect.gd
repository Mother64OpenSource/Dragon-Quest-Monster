class_name HopefulHitterTraitEffect
extends TraitEffect

## "Attacks often miss the mark, but can deliver critical hits" -- trades
## accuracy for crit chance.

@export var accuracy_multiplier: float = 0.75
@export var crit_multiplier: float = 2.0

func get_accuracy_multiplier() -> float:
	return accuracy_multiplier

func get_crit_chance_multiplier(_owner: MonsterInstance, _category: int) -> float:
	return crit_multiplier
