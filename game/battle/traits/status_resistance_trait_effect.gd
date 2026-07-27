class_name StatusResistanceTraitEffect
extends TraitEffect

## Generic "X Ward" status-resistance trait (Confusion/Curse/Dazzle/
## Gobstopper/Paralysis/Poison/Sleep Ward, plus Inaction Ward -> immobilize
## and Fizzle Ward -> silence): reduces the chance a matching status
## actually lands on the owner. Confirmed against the real skill data
## before building this -- every skill that carries e.g. `element: "Poison"`
## also carries a real StatusEffect(status_id="poison") alongside its
## damage, so this is a genuinely distinct mechanic from the elemental-
## damage Ward family (ElementalDamageResistanceTraitEffect), not a
## reskin of it. Mirrors that class's own placeholder magnitude (0.75 here
## = a 25% chance reduction, vs that class's 0.25 damage reduction) for
## consistency across the whole Ward family -- no sourced real percentage
## exists for either.

@export var status_ids: Array[String] = []
@export var resistance_multiplier: float = 0.75

func get_status_resistance_multiplier(status_id: String) -> float:
	return resistance_multiplier if status_ids.has(status_id) else 1.0
