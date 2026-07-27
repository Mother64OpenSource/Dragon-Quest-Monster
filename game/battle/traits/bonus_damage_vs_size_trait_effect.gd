class_name BonusDamageVsSizeTraitEffect
extends TraitEffect

## Generic "deals a heavy blow to monsters of a specific size tier" trait
## (Giant Killer vs Giant-tier, Standard Killer vs "smaller monsters" --
## interpreted literally as Small-tier). Keyed off MonsterSpecies.slots
## directly rather than a new field: cross-checked the real source
## spreadsheet's own Size column (a letter + bracket number, S[1]/P[2]/
## H[3]/G[4]) against every one of this project's 803 imported monsters
## and found zero mismatches against the already-imported `slots` field --
## it turns out `slots` (imported earlier for the party-formation
## slot-cost mechanic) already IS the monster's size tier, so no new field
## or re-import is needed to build this.

@export var target_slots: int = 4
@export var damage_multiplier: float = 1.3

func on_before_damage_dealt(_ctx: BattleContext, _owner: MonsterInstance, target: MonsterInstance, incoming_damage: int, _element: String = "") -> int:
	if target.species.slots != target_slots:
		return incoming_damage
	return MathUtils.round_half_up(float(incoming_damage) * damage_multiplier)
