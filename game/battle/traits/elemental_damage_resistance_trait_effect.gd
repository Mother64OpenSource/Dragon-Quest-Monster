class_name ElementalDamageResistanceTraitEffect
extends TraitEffect

## Generic "X-type Ward" trait: reduces incoming damage from a hit whose
## element matches ANY of `elements` (almost always exactly one, e.g.
## Frizz Ward -> ["Frizz"] -- breath-family wards are the one case with a
## real reason to list more than one). Uses a CONTAINS check against the
## hit's own element string, not exact equality, since some real moves
## carry a compound element ("Frizz-Fire", a breath attack that's both) --
## a Frizz Ward should still reduce a Frizz-Fire hit, not just a bare
## "Frizz" one.

@export var elements: Array[String] = []
@export var reduction_percent: float = 0.25

func on_before_damage_taken(_ctx: BattleContext, _owner: MonsterInstance, _attacker: MonsterInstance, incoming_damage: int, hit_element: String = "") -> int:
	if hit_element.is_empty() or not _matches(hit_element):
		return incoming_damage
	return maxi(0, MathUtils.round_half_up(float(incoming_damage) * (1.0 - reduction_percent)))

func _matches(hit_element: String) -> bool:
	for element in elements:
		if hit_element.contains(element):
			return true
	return false
