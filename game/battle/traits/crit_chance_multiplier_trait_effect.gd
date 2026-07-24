class_name CritChanceMultiplierTraitEffect
extends TraitEffect

## Generic crit-chance booster. category_filter == -1 applies to every
## damage category (Critical Massacre); set to a specific
## DamageEffect.Category value to apply only there (Spell Satisfaction ->
## DamageEffect.Category.MAGIC).

@export var multiplier: float = 2.0
@export var category_filter: int = -1

func get_crit_chance_multiplier(_owner: MonsterInstance, category: int) -> float:
	if category_filter == -1 or category == category_filter:
		return multiplier
	return 1.0
