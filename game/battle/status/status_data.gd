class_name StatusData
extends Resource

## Fully data-driven condition definition. A new status condition should
## mean a new fixture (or new field values), not a new subclass.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon_path: String = ""
@export var tick_damage_percent: float = 0.0
@export var skip_turn_chance: float = 0.0
## Non-empty means the afflicted monster can't use a skill of this
## SkillData.Category name ("magic" for Silence/Fizzled, "skill" for
## Gobstop/Skill-Sealed) -- basic Attack (category "physical") always stays
## usable, matching the real games' distinction between "can't move at all"
## (skip_turn_chance) and "can't use certain moves."
@export var blocked_skill_category: String = ""
## Multiplies a PHYSICAL skill's accuracy for the afflicted monster's own
## attacks (Dazzle/Dazzled: "much more likely to miss with physical
## attacks"). 1.0 (default) means no penalty.
@export var accuracy_multiplier: float = 1.0
## Sleep-specific: taking any damage clears the status early, same as the
## real games' "cannot act until awoken by an attack."
@export var wakes_on_damage: bool = false
@export var duration_turns: int = 3
@export var stat_mods_on_apply: Array[StatModEffect] = []

static func load_from_dict(data: Dictionary) -> StatusData:
	var status := StatusData.new()
	status.id = data.get("id", "")
	status.display_name = data.get("display_name", status.id)
	status.description = data.get("description", "")
	status.icon_path = data.get("icon_path", "")
	status.tick_damage_percent = float(data.get("tick_damage_percent", 0.0))
	status.skip_turn_chance = float(data.get("skip_turn_chance", 0.0))
	status.blocked_skill_category = data.get("blocked_skill_category", "")
	status.accuracy_multiplier = float(data.get("accuracy_multiplier", 1.0))
	status.wakes_on_damage = bool(data.get("wakes_on_damage", false))
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
