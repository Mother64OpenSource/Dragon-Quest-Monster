class_name StatModResistanceTraitEffect
extends TraitEffect

## Generic "X Ward" stat-debuff-resistance trait (Sag Ward, Sap Ward,
## Decelerate Ward): reduces the chance a matching stat-debuff spell
## actually lands on the owner. Confirmed against real skill data before
## building this -- sag.json/sap.json/decelerate.json are pure StatModEffect
## debuffs with no StatusEffect attached at all, a genuinely different gap
## from the status-flavored Ward cluster (StatusResistanceTraitEffect).
## Mirrors that class's own placeholder magnitude (0.75) for consistency
## across the whole Ward family -- no sourced real percentage exists here
## either.

@export var elements: Array[String] = []
@export var resistance_multiplier: float = 0.75

func get_stat_mod_resistance_multiplier(element: String) -> float:
	return resistance_multiplier if elements.has(element) else 1.0
