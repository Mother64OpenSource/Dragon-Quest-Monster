class_name MonsterLoadout
extends Resource

## A team member's configuration — what a saved team stores, distinct from
## MonsterInstance (battle-runtime state). "" nickname means "use the
## species' display_name" at battle-bridge time (a later milestone).

@export var species_id: String = ""
@export var nickname: String = ""
@export var equipped_skill_ids: Array[String] = []
