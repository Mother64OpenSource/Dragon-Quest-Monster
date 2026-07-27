class_name BonusDamageVsMetalBodyTraitEffect
extends TraitEffect

## Flat damage bonus against a target that has any of the metal-body family
## of traits active (metal_body/light/hard/superhard) -- covers Hunter Mech
## ("damage inflicted on enemies with metal bodies will increase by 1
## point"). Checks the target's active_traits rather than species.family,
## since "metal body" is a trait some non-Metal-family monsters also carry
## (e.g. Metal Slime is species family "Slime").

const METAL_BODY_TRAIT_IDS := ["metal_body", "light_metal_body", "hard_metal_body", "superhard_metal_body"]

@export var flat_bonus: int = 1

func on_before_damage_dealt(_ctx: BattleContext, _owner: MonsterInstance, target: MonsterInstance, incoming_damage: int, _element: String = "") -> int:
	for trait_effect in target.active_traits:
		if trait_effect.trait_data != null and METAL_BODY_TRAIT_IDS.has(trait_effect.trait_data.id):
			return incoming_damage + flat_bonus
	return incoming_damage
