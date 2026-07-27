class_name DamageReductionTraitEffect
extends TraitEffect

## Generic percent-based damage-taken reduction, parameterized so one class
## covers every "take a fraction of damage" trait (light/hard/superhard
## metal body) rather than a bespoke subclass per fraction. metal_body
## itself keeps its own MetalBodyTraitEffect, already shipped and tested.

@export var damage_reduction_percent: float = 0.5

func on_before_damage_taken(_ctx: BattleContext, _owner: MonsterInstance, _attacker: MonsterInstance, incoming_damage: int, _element: String = "") -> int:
	return maxi(0, MathUtils.round_half_up(float(incoming_damage) * (1.0 - damage_reduction_percent)))
