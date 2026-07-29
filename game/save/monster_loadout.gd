class_name MonsterLoadout
extends Resource

## A team member's configuration — what a saved team stores, distinct from
## MonsterInstance (battle-runtime state). "" nickname means "use the
## species' display_name" at battle-bridge time (a later milestone).

@export var species_id: String = ""
@export var nickname: String = ""

## skillset_id -> points invested. Every known skill and trait this monster
## actually has comes from this Dictionary's keys/values -- there is no
## separate "equip a subset of what you've unlocked" step (that's not how
## these games work: crossing a threshold means you simply know that move
## or carry that trait, permanently, no picking and choosing which of your
## already-crossed thresholds to keep). See
## TeamRosterManager.get_unlocked_skill_ids()/get_active_trait_ids(), the
## real functions of record for "what does this monster actually have."
## Capped at species.slots+2 simultaneous keys (enforced by
## TeamRosterManager.validate_member, not here) -- there's no shared
## cross-panel *point* pool (skill points are effectively unlimited via
## farmable skill seeds), but the number of skillset *slots* really is
## limited, same as the real games.
@export var skill_point_allocation: Dictionary = {}

## "" means no weapon equipped. Should be a WeaponData whose type is in
## MonsterEquipmentRules.get_equippable_weapon_types(species) (enforced by
## TeamRosterManager.validate_member, not here -- same pattern as
## skill_point_allocation above).
@export var equipped_weapon_id: String = ""

## BlacksmithItemData ids permanently applied to this monster. Any species
## can receive any item (no compatibility grid exists for these, unlike
## weapons) -- resolved at battle-bridge time (see TeamToBattleBridge).
@export var crafted_blacksmith_ids: Array[String] = []

## 0 means "use the species' own natural MonsterSpecies.slots" (a sentinel,
## same convention as this file's own "" nickname above) -- a nonzero value
## (1-4) means this monster has been reborn into a bigger size than its
## natural one, unlocking that species' own size_gated_trait_ids up to
## whichever of the P (2+)/H (3+)/G (4) tiers this value reaches. Real DQM
## reborn also requires actually reaching +★ first and performing a reborn
## action -- deliberately not simulated here, since this is a team-builder
## sandbox, not a persistent breeding metagame (see wiki/log.md); it's just
## a directly-editable number, same "configure anything, no grinding gate"
## precedent as skill_point_allocation above.
@export var current_size: int = 0

## The monster's synthesis stack ("+N"), 0-100 ("+★" = +100 exactly, despite
## the in-game display). Unlocks that species' own synth_gated_trait_ids up
## to whichever of the 25/50/star tiers this value reaches. 0 is a real,
## valid value (a wild, never-fused monster), not a sentinel like
## current_size above.
@export var synthesis_stack: int = 0
