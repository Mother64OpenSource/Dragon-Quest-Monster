class_name MpCostAndDamageTraitEffect
extends TraitEffect

## Generic "skills cost more/less MP, optionally hitting harder too" trait
## (Magic Miser, Magic Scrooge, Spell Splurger, Strong/Ultra Guard Break,
## Crafty Devil). damage_multiplier defaults to 1.0 (no change) for the
## MP-only pair (Magic Miser/Scrooge) and Spell Splurger, which reads as a
## pure drawback in its own description (no matching benefit mentioned).

@export var mp_cost_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0

func get_mp_cost_multiplier(_skill: SkillData) -> float:
	return mp_cost_multiplier

func on_before_damage_dealt(_ctx: BattleContext, _owner: MonsterInstance, _target: MonsterInstance, incoming_damage: int, _element: String = "") -> int:
	if damage_multiplier == 1.0:
		return incoming_damage
	return MathUtils.round_half_up(float(incoming_damage) * damage_multiplier)
