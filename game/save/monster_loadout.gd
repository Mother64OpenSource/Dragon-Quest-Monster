class_name MonsterLoadout
extends Resource

## A team member's configuration — what a saved team stores, distinct from
## MonsterInstance (battle-runtime state). "" nickname means "use the
## species' display_name" at battle-bridge time (a later milestone).

@export var species_id: String = ""
@export var nickname: String = ""
@export var equipped_skill_ids: Array[String] = []

## skillset_id -> points invested. Keys should be a subset of the species'
## available_skill_sets; each value should not exceed that skillset's own
## max defined threshold (enforced by TeamRosterManager.validate_member, not
## here) -- there's no shared cross-panel point pool, since skill points are
## effectively unlimited via farmable skill seeds.
@export var skill_point_allocation: Dictionary = {}

## "" means no weapon equipped. Should be a WeaponData whose type is in
## MonsterEquipmentRules.get_equippable_weapon_types(species) (enforced by
## TeamRosterManager.validate_member, not here -- same pattern as
## equipped_skill_ids above).
@export var equipped_weapon_id: String = ""

## BlacksmithItemData ids permanently applied to this monster. Any species
## can receive any item (no compatibility grid exists for these, unlike
## weapons) -- resolved at battle-bridge time (see TeamToBattleBridge).
@export var crafted_blacksmith_ids: Array[String] = []
