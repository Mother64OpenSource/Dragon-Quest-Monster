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

## "" means no artwork available yet — callers must handle the missing case.
@export var sprite_path: String = ""

## Skill panel ids this species can invest skill points into (see
## SkillSetData). Order is significant only for UI display -- typically
## [own dedicated panel, then 0-2 shared panels].
@export var available_skill_sets: Array[String] = []

## Synthesis slot count (1-4), sourced from the sheet's "Size" column (e.g.
## "S [1]", "G [4]"). Determines total available skill panels: slots + 2
## (see MonsterSpecies.available_skill_sets / total_skill_points).
@export var slots: int = 1

## Total skill points this species has to allocate across available_skill_sets
## (see MonsterLoadout.skill_point_allocation). A rank-based placeholder,
## since there's no leveling/EXP system yet to derive this from -- see
## wiki/log.md.
@export var total_skill_points: int = 0

## Sparse map of resistance-code -> raw symbol from the source spreadsheet
## (e.g. "Psn": "½", "Zap": "0"). Only non-blank entries are stored; a code
## absent from this dict means normal (unmodified) susceptibility. Symbol
## meaning is not yet formalized into game mechanics -- see
## wiki/decisions or the log for the open question on exact semantics
## (½ = resist, ↓ = weak, 0 = immune, ⁎/↑/↑↑/⇄ still unconfirmed).
@export var resistances: Dictionary = {}
