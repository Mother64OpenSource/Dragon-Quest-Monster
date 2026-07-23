extends SceneTree

## One-off utility: persists each monster's synthesis slot count (already
## used transiently to compute skill-panel quotas -- see
## import_skill_panels.gd -- but never actually written to the fixtures)
## onto MonsterSpecies as a real field.
## Run via: godot --headless --script res://tests/tools/import_slots.gd

const SCRATCH := "C:/Users/elivo/AppData/Local/Temp/claude/D--Dragon-Quest-Monster-Showdown/33389280-0d18-448d-bdab-bc0185796eb1/scratchpad"
const MONSTER_FIXTURES_DIR := "res://database/monsters/fixtures"

func _initialize() -> void:
	var slots_rows: Array = _load_json(SCRATCH + "/monster_slots.json")
	var no_to_id := _load_tsv(SCRATCH + "/no_id_fixed.tsv")

	var slots_by_no := {}
	for row in slots_rows:
		slots_by_no[row["No"]] = int(row["Slots"])

	var updated := 0
	for no in slots_by_no:
		if not no_to_id.has(no):
			continue
		var monster_id: String = no_to_id[no]
		var path := MONSTER_FIXTURES_DIR + "/" + monster_id + ".json"
		if not FileAccess.file_exists(path):
			continue
		var f := FileAccess.open(path, FileAccess.READ)
		var text := f.get_as_text()
		f.close()
		var json := JSON.new()
		if json.parse(text) != OK:
			print("PARSE ERROR: ", path)
			continue
		var data: Dictionary = json.data
		data["slots"] = slots_by_no[no]
		var out := FileAccess.open(path, FileAccess.WRITE)
		out.store_string(JSON.stringify(data, "\t"))
		out.close()
		updated += 1

	print("Monsters updated with slots: ", updated)
	quit(0)

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

func _load_tsv(path: String) -> Dictionary:
	var result := {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		print("Cannot open: ", path)
		return result
	while not f.eof_reached():
		var line := f.get_line()
		if line.is_empty():
			continue
		var parts := line.split("\t")
		if parts.size() >= 2:
			result[parts[0]] = parts[1]
	f.close()
	return result
