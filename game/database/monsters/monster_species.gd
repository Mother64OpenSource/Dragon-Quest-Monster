class_name MonsterSpecies
extends Resource

## Static per-species data, shared/read-only across every MonsterInstance of
## the same species. No behavior lives here.

## Ascending strength order (matches the classic DQM rank ladder) so filters
## can compare ordinally (e.g. rank >= Rank.C), not just check equality.
## SS is the top tier above S, used by the game's strongest monsters.
enum Rank { F, E, D, C, B, A, S, SS }

@export var id: String = ""
@export var display_name: String = ""
@export var family: String = ""
@export var rank: Rank = Rank.F
@export var base_hp: int = 1
@export var base_mp: int = 0
@export var base_attack: int = 1
@export var base_defense: int = 1
@export var base_agility: int = 1
@export var base_wisdom: int = 1
@export var starting_skill_ids: Array[String] = []
@export var starting_trait_ids: Array[String] = []

## Traits unlocked once a monster is reborn into a bigger size than its
## natural one -- sparse map of tier code ("P" = 2+ slots, "H" = 3+ slots,
## "G" = 4 slots) -> Array[String] of trait ids, sourced from the source
## sheet's own per-monster "If Size [P/H/G]" line. A tier absent from this
## dict means this species has no trait gated on it. See
## MonsterLoadout.current_size / TeamRosterManager.get_active_trait_ids()
## for how these actually get folded into a monster's real trait list.
@export var size_gated_trait_ids: Dictionary = {}

## Traits unlocked once a monster's synthesis stack ("+N", capping at "+★"
## i.e. +100) crosses a threshold -- sparse map of tier code ("25"/"50"/
## "star") -> Array[String] of trait ids, sourced from the source sheet's
## own per-monster "If Rank Offset [+25/+50/+★]" line. See
## MonsterLoadout.synthesis_stack / TeamRosterManager.get_active_trait_ids().
@export var synth_gated_trait_ids: Dictionary = {}

## "" means no artwork available yet — callers must handle the missing case.
@export var sprite_path: String = ""

## Skill panel ids this species can invest skill points into (see
## SkillSetData). Order is significant only for UI display -- typically
## [own dedicated panel, then 0-2 shared panels].
@export var available_skill_sets: Array[String] = []

## Synthesis slot count (1-4), sourced from the sheet's "Size" column (e.g.
## "S [1]", "G [4]"). Determines total available skill panels: slots + 2
## (see MonsterSpecies.available_skill_sets).
@export var slots: int = 1

## Weapon-type ids ("sword"/"spear"/"axe"/"club"/"whip"/"claw"/"staff", see
## WeaponData.ALL_TYPE_IDS) this species can equip, sourced from the source
## spreadsheet's Monsters tab Weapons compatibility grid (a blank cell means
## compatible, "⨯" means not -- not every species can equip every type, e.g.
## most Slime-family monsters can't use Claw or Staff weapons). Prefer
## MonsterEquipmentRules.get_equippable_weapon_types() over reading this
## directly, since it also accounts for the master_of_weapons trait -- kept
## as raw sourced data here rather than a method, matching this class's own
## "no behavior lives here" convention.
@export var equippable_weapon_types: Array[String] = []

## Sparse map of resistance-code -> raw symbol from the source spreadsheet
## (e.g. "Psn": "½", "Zap": "0"). Only non-blank entries are stored; a code
## absent from this dict means normal (unmodified) susceptibility. Symbol
## meaning is not yet formalized into game mechanics -- see
## wiki/decisions or the log for the open question on exact semantics
## (½ = resist, ↓ = weak, 0 = immune, ⁎/↑/↑↑/⇄ still unconfirmed).
@export var resistances: Dictionary = {}
