class_name MonsterSpecies
extends Resource

## Static per-species data, shared/read-only across every MonsterInstance of
## the same species. No behavior lives here.

@export var id: String = ""
@export var display_name: String = ""
@export var family: String = ""
@export var base_hp: int = 1
@export var base_mp: int = 0
@export var base_attack: int = 1
@export var base_defense: int = 1
@export var base_agility: int = 1
@export var base_wisdom: int = 1
@export var starting_skill_ids: Array[String] = []
@export var starting_trait_ids: Array[String] = []
