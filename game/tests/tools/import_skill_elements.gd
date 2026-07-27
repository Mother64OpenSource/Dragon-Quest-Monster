extends SceneTree

## One-off utility: adds SkillData.element (the real elemental/status
## Attribute value from the source spreadsheet's Abilities tab, e.g.
## "Frizz", "Zap", "Fire", "Frizz-Fire", but also non-elemental values like
## "Poison"/"Confusion"/"Sap" verbatim -- storing those too is harmless now
## and saves a future re-import once THOSE traits get their own subsystem)
## onto every already-imported skill fixture.
##
## Why this exists: the earlier moveset import (import_movesets.gd) already
## read this exact "Attribute" column to decide each move's effect TYPE, but
## never kept the raw value on SkillData itself -- so the ~60 elemental
## trait names (every Ward/-meister/crafty_X trait) had nothing to key off
## of. See wiki/log.md.
##
## Run via: godot --headless --script res://tests/tools/import_skill_elements.gd

const SCRATCH := "C:/Users/elivo/AppData/Local/Temp/claude/D--Dragon-Quest-Monster-Showdown/33389280-0d18-448d-bdab-bc0185796eb1/scratchpad"
const SKILLS_FIXTURES_DIR := "res://database/skills/fixtures"

var _updated_count := 0
var _skipped_no_attribute := 0
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

	print("Skill fixtures updated with a real element: ", _updated_count)
	print("Skill fixtures with no elemental attribute (physical Attack, etc.): ", _skipped_no_attribute)
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
		_skipped_no_attribute += 1
		return

	var ability: Dictionary = ability_by_name[display_name]
	var attribute: String = ability.get("Attribute", "-")
	if attribute == "-" or attribute.is_empty():
		_skipped_no_attribute += 1
		return

	data["element"] = attribute
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
