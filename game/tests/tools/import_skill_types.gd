extends SceneTree

## One-off utility: adds SkillData.skill_type (the source spreadsheet's own
## "Type" column -- Spell/Slash/Body/Dance/Breath/Other, a coarser,
## orthogonal breakdown from the "Attribute" column import_skill_elements.gd
## already did) onto every already-imported skill fixture.
##
## Why this exists: abilities.json (the exact same cached scratch file
## import_skill_elements.gd already reads) turned out to carry this second
## column too, never previously imported -- unlocking the small
## combat-archetype trait cluster (Great Sage/Warrior/Combat King/Deadly
## Breath/Dance Meister/Divine Dancer) that keys off it. See wiki/log.md.
##
## Run via: godot --headless --script res://tests/tools/import_skill_types.gd

const SCRATCH := "C:/Users/elivo/AppData/Local/Temp/claude/D--Dragon-Quest-Monster-Showdown/33389280-0d18-448d-bdab-bc0185796eb1/scratchpad"
const SKILLS_FIXTURES_DIR := "res://database/skills/fixtures"

var _updated_count := 0
var _unmatched_names: Dictionary = {}

func _initialize() -> void:
	var abilities: Array = _load_json(SCRATCH + "/abilities.json")
	var ability_by_name := {}
	for a in abilities:
		ability_by_name[a["English"]] = a

	var dir := DirAccess.open(SKILLS_FIXTURES_DIR)
	if dir == null:
		print("Cannot open skills fixtures dir")
		quit(1)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_process_fixture(SKILLS_FIXTURES_DIR + "/" + file_name, ability_by_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("Skill fixtures updated with a real skill_type: ", _updated_count)
	print("Display names with no match in abilities.json (left as-is, likely M1 hand-tuned): ", _unmatched_names.size())
	for name in _unmatched_names:
		print("  unmatched: ", name)
	quit(0)

func _process_fixture(path: String, ability_by_name: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		print("PARSE ERROR: ", path)
		return
	var data: Dictionary = json.data

	var display_name: String = data.get("display_name", "")
	if not ability_by_name.has(display_name):
		_unmatched_names[display_name] = true
		return

	var ability: Dictionary = ability_by_name[display_name]
	var skill_type: String = ability.get("Type", "")
	if skill_type.is_empty():
		return

	data["skill_type"] = skill_type
	_updated_count += 1

	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_string(JSON.stringify(data, "\t"))
	out.close()

func _load_json(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		print("Cannot open: ", path)
		return []
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		print("PARSE ERROR: ", path)
		return []
	return json.data
