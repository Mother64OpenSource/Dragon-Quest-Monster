class_name ExtraAttackTraitEffect
extends TraitEffect

## Generic "acts multiple times in a row this turn" trait (Hit Squad).
## extra_attacks is on top of the one action the monster already gets --
## 1 means it attacks twice total, not once.

@export var extra_attacks: int = 0

func get_extra_attack_count() -> int:
	return extra_attacks
