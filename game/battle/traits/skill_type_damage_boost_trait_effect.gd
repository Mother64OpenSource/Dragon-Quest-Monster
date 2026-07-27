class_name SkillTypeDamageBoostTraitEffect
extends TraitEffect

## Generic "boosts a whole category of skills" combat-archetype trait
## (Great Sage -> Spell, Warrior -> Slash, Combat King -> Body, Deadly
## Breath -> Breath, Dance Meister/Divine Dancer -> Dance). Keyed off
## SkillData.skill_type/DamageEffect.skill_type (the source spreadsheet's
## "Type" column: Spell/Slash/Body/Dance/Breath/Other), an orthogonal,
## coarser breakdown from `element` -- e.g. Frizz and Zap are both "Spell,"
## Attack and Hatchet Man are both "Slash." Exact-equality matching, unlike
## the elemental Ward/-meister classes' CONTAINS check, since Type values
## are single discrete categories with no compound values the way elements
## have ("Frizz-Fire").
##
## mp_cost_multiplier defaults to 1.0 (no change) -- only Dance Meister's
## own description mentions an MP discount alongside its damage boost
## (mirroring how the elemental -meister/crafty_X split already works);
## Divine Dancer and the other three registrations here leave it untouched.

@export var skill_types: Array[String] = []
@export var damage_multiplier: float = 1.2
@export var mp_cost_multiplier: float = 1.0

func get_skill_type_damage_multiplier(skill_type: String) -> float:
	return damage_multiplier if skill_types.has(skill_type) else 1.0

func get_mp_cost_multiplier(skill: SkillData) -> float:
	return mp_cost_multiplier if skill_types.has(skill.skill_type) else 1.0
