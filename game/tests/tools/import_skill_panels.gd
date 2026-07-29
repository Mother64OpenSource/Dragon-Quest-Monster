extends SceneTree

## One-off utility: builds SkillSetData fixtures (skill panels with SP
## thresholds) and rewires every monster fixture to reference its available
## panels + a rank-based skill point pool, replacing the flat moveset from
## the previous import pass. See wiki/log.md for full rationale.
##
## Its own panel-fixture-writing step is superseded by
## import_skillsets_full.gd, which regenerates every one of the 384 real
## skillsets (this script only ever wrote the 220 referenced by at least one
## monster's own curated list) and also captures trait-granting thresholds
## this script's own _build_thresholds() silently dropped. Still the source
## of truth for starting_skill_ids/available_skill_sets on monster fixtures.
##
## Run via: godot --headless --script res://tests/tools/import_skill_panels.gd

const SCRATCH := "C:/Users/elivo/AppData/Local/Temp/claude/D--Dragon-Quest-Monster-Showdown/33389280-0d18-448d-bdab-bc0185796eb1/scratchpad"
const SKILLSETS_FIXTURES_DIR := "res://database/skillsets/fixtures"
const MONSTER_FIXTURES_DIR := "res://database/monsters/fixtures"

const STAT_BOOST_REGEX := "^([A-Z]{2,4})\\s*\\+\\s*(\\d+)$"
const STAT_CODE_MAP := {"ATK": "attack", "DEF": "defense", "AGI": "agility", "WIS": "wisdom", "HP": "hp", "MP": "mp"}


var _stat_boost_re: RegEx

func _initialize() -> void:
	_stat_boost_re = RegEx.new()
	_stat_boost_re.compile(STAT_BOOST_REGEX)

	var abilities: Array = _load_json(SCRATCH + "/abilities.json")
	var skillsets: Array = _load_json(SCRATCH + "/skillsets.json")
	var monster_available: Array = _load_json(SCRATCH + "/monster_available_skillsets.json")
	var no_to_id := _load_tsv(SCRATCH + "/no_id_fixed.tsv")

	print("Loaded: %d abilities, %d skillsets, %d monster-available rows, %d no->id" % [
		abilities.size(), skillsets.size(), monster_available.size(), no_to_id.size()
	])

	var ability_names := {}
	for a in abilities:
		ability_names[a["English"]] = true

	var skillset_by_name := {}
	for s in skillsets:
		skillset_by_name[s["English"]] = s

	# Which skillset names are actually referenced by at least one monster.
	var referenced_names := {}
	for row in monster_available:
		for name in row["AvailableSkillsets"]:
			referenced_names[name] = true

	var name_to_id := {}
	var skillsets_written := 0
	for name in referenced_names:
		var id := _slugify(name)
		name_to_id[name] = id
		if not skillset_by_name.has(name):
			print("WARNING: no skillset data for referenced name: ", name)
			continue
		var thresholds := _build_thresholds(skillset_by_name[name]["Moves"], ability_names)
		_write_json(SKILLSETS_FIXTURES_DIR + "/" + id + ".json", {
			"id": id,
			"display_name": name,
			"thresholds": thresholds,
		})
		skillsets_written += 1

	var monsters_updated := 0
	for row in monster_available:
		var no: String = row["No"]
		if not no_to_id.has(no):
			continue
		var monster_id: String = no_to_id[no]
		var path := MONSTER_FIXTURES_DIR + "/" + monster_id + ".json"
		if not FileAccess.file_exists(path):
			continue

		var available_ids: Array = []
		for name in row["AvailableSkillsets"]:
			if name_to_id.has(name):
				available_ids.append(name_to_id[name])

		var f := FileAccess.open(path, FileAccess.READ)
		var text := f.get_as_text()
		f.close()
		var json := JSON.new()
		if json.parse(text) != OK:
			print("PARSE ERROR: ", path)
			continue
		var data: Dictionary = json.data
		data["starting_skill_ids"] = ["attack"]
		data["available_skill_sets"] = available_ids
		_write_json(path, data)
		monsters_updated += 1

	print("Skillset fixtures written: ", skillsets_written)
	print("Monsters updated: ", monsters_updated)
	quit(0)

func _build_thresholds(moves: Array, ability_names: Dictionary) -> Array:
	var thresholds: Array = []
	for m in moves:
		var name: String = m["name"]
		var sp := int(m["sp"]) if (m["sp"] as String).is_valid_int() else 0

		var boost_match := _stat_boost_re.search(name)
		if boost_match != null:
			var code := boost_match.get_string(1)
			var amount := int(boost_match.get_string(2))
			if STAT_CODE_MAP.has(code):
				thresholds.append({"sp": sp, "kind": "stat_boost", "stat_name": STAT_CODE_MAP[code], "amount": amount})
			continue

		if ability_names.has(name):
			thresholds.append({"sp": sp, "kind": "skill", "skill_id": _slugify(name)})
		# else: passive perk/ward/trait with no ability match -- omitted, same
		# exclusion as the previous moveset-only import pass.
	return thresholds

func _slugify(name: String) -> String:
	var result := ""
	for c in name:
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
			result += c
		else:
			result += "_"
	while result.contains("__"):
		result = result.replace("__", "_")
	result = result.trim_prefix("_").trim_suffix("_")
	return result.to_lower()

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

func _write_json(path: String, data: Dictionary) -> void:
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_string(JSON.stringify(data, "\t"))
	out.close()
