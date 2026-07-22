class_name StatusData
extends Resource

## Fully data-driven condition definition. A new status condition should
## mean a new fixture (or new field values), not a new subclass.

@export var id: String = ""
@export var display_name: String = ""
@export var tick_damage_percent: float = 0.0
@export var skip_turn_chance: float = 0.0
@export var duration_turns: int = 3
@export var stat_mods_on_apply: Array[StatModEffect] = []

static func load_from_dict(data: Dictionary) -> StatusData:
	var status := StatusData.new()
	status.id = data.get("id", "")
	status.display_name = data.get("display_name", status.id)
	status.tick_damage_percent = float(data.get("tick_damage_percent", 0.0))
	status.skip_turn_chance = float(data.get("skip_turn_chance", 0.0))
	status.duration_turns = int(data.get("duration_turns", 3))

	var mods: Array[StatModEffect] = []
	for mod_data in data.get("stat_mods_on_apply", []):
		var mod := StatModEffect.new()
		mod.stat_name = mod_data.get("stat_name", "attack")
		mod.stages = int(mod_data.get("stages", 1))
		mod.chance = float(mod_data.get("chance", 1.0))
		mod.target_self = bool(mod_data.get("target_self", true))
		mods.append(mod)
	status.stat_mods_on_apply = mods
	return status

static func load_from_file(path: String) -> StatusData:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("Failed to parse status JSON: %s" % path)
		return null
	return load_from_dict(parsed)
