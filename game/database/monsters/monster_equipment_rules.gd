class_name MonsterEquipmentRules
extends RefCounted

## Small, standalone equip-eligibility rule -- same "static helper over a
## data class" shape as TeamFormationLayout, so MonsterSpecies itself can
## stay pure data.

## master_of_weapons ("Allows monster to equip every type of weapon") is an
## equip-eligibility rule, not a battle-runtime hook, so it's special-cased
## here by trait id rather than going through TraitEffect.create() -- same
## "read a trait id directly" pattern BonusDamageVsMetalBodyTraitEffect
## already uses for a different trait.
const MASTER_OF_WEAPONS_TRAIT_ID := "master_of_weapons"

static func get_equippable_weapon_types(species: MonsterSpecies) -> Array[String]:
	if species.starting_trait_ids.has(MASTER_OF_WEAPONS_TRAIT_ID):
		var all_types: Array[String] = WeaponData.ALL_TYPE_IDS.duplicate()
		return all_types
	return species.equippable_weapon_types

static func can_equip(species: MonsterSpecies, weapon: WeaponData) -> bool:
	if weapon == null:
		return false
	var type_id := WeaponLoader.type_to_string(weapon.weapon_type)
	return get_equippable_weapon_types(species).has(type_id)
