class_name PriorityBonusTraitEffect
extends TraitEffect

## Generic turn-order shift, parameterized so one class covers every
## "always acts first/last"-style trait. Magnitudes just need to dominate
## the existing small per-skill priority range (see ActionResolver).

@export var priority_bonus: int = 0

func get_priority_bonus() -> int:
	return priority_bonus
