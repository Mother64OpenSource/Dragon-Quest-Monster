class_name SavedTeam
extends Resource

## A named, ordered team of MonsterLoadouts. id is a stable, slugified,
## runtime-generated identifier used as the storage filename key.

@export var id: String = ""
@export var team_name: String = ""
@export var members: Array[MonsterLoadout] = []
