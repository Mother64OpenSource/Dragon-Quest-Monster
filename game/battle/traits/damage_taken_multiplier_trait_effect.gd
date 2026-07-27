class_name DamageTakenMultiplierTraitEffect
extends TraitEffect

## Attalleric: "Increases damage received" -- a flat, unconditional
## (non-elemental, always-on) multiplier on incoming damage. No sourced
## real percentage exists -- a documented placeholder, same honesty
## convention as every other invented numeric constant in this project.

@export var multiplier: float = 1.2

func on_before_damage_taken(_ctx: BattleContext, _owner: MonsterInstance, _attacker: MonsterInstance, incoming_damage: int, _element: String = "") -> int:
	return MathUtils.round_half_up(float(incoming_damage) * multiplier)
