class_name ElementalDamageBoostTraitEffect
extends TraitEffect

## Generic "-meister"/"crafty_X" trait: boosts the OWNER's own damage
## (and, for the -meister family specifically, discounts MP cost too --
## the crafty_X family only ever mentions the damage boost, never an MP
## change, hence these two multipliers being independent) for skills whose
## element matches ANY of `elements`. Same CONTAINS-against-any-of-a-list
## matching as ElementalDamageResistanceTraitEffect, for the same reason
## (compound elements, and multi-element traits like Breath Meister).

@export var elements: Array[String] = []
@export var damage_multiplier: float = 1.2
@export var mp_cost_multiplier: float = 1.0

func on_before_damage_dealt(_ctx: BattleContext, _owner: MonsterInstance, _target: MonsterInstance, incoming_damage: int, hit_element: String = "") -> int:
	if hit_element.is_empty() or not _matches(hit_element):
		return incoming_damage
	return MathUtils.round_half_up(float(incoming_damage) * damage_multiplier)

func get_mp_cost_multiplier(skill: SkillData) -> float:
	if skill.element.is_empty() or not _matches(skill.element):
		return 1.0
	return mp_cost_multiplier

func _matches(element: String) -> bool:
	for candidate in elements:
		if element.contains(candidate):
			return true
	return false
