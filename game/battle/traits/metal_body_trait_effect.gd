class_name MetalBodyTraitEffect
extends TraitEffect

@export var damage_reduction_percent: float = 0.5

func on_before_damage_taken(_ctx: BattleContext, _owner: MonsterInstance, _attacker: MonsterInstance, incoming_damage: int, _element: String = "") -> int:
	return maxi(0, MathUtils.round_half_up(float(incoming_damage) * (1.0 - damage_reduction_percent)))
