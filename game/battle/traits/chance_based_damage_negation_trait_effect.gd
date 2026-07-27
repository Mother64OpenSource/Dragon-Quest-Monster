class_name ChanceBasedDamageNegationTraitEffect
extends TraitEffect

## Generic "dodge or block" effect: rolls a chance to zero out incoming
## damage entirely. Covers both true dodges (Artful Dodger) and damage
## blocks (Perilous Parrier) -- the existing on_before_damage_taken hook
## already supports "return 0" without any new engine plumbing.

@export var chance: float = 0.0
## If non-empty, an attacker carrying this trait id suppresses the roll
## entirely (Fly Swatter negates Artful Dodger) -- checked the same way
## BonusDamageVsMetalBodyTraitEffect reads the other combatant's trait id.
@export var blocked_by_trait_id: String = ""
## Applied to the damage when the roll fails (Perilous Parrier's "greatly
## increases incoming damage" otherwise). 1.0 = no change.
@export var damage_multiplier_otherwise: float = 1.0

func on_before_damage_taken(ctx: BattleContext, _owner: MonsterInstance, attacker: MonsterInstance, incoming_damage: int, _element: String = "") -> int:
	if not blocked_by_trait_id.is_empty():
		for trait_effect in attacker.active_traits:
			if trait_effect.trait_data != null and trait_effect.trait_data.id == blocked_by_trait_id:
				return incoming_damage
	if ctx.rng.chance(chance):
		return 0
	if damage_multiplier_otherwise != 1.0:
		return maxi(0, MathUtils.round_half_up(float(incoming_damage) * damage_multiplier_otherwise))
	return incoming_damage
