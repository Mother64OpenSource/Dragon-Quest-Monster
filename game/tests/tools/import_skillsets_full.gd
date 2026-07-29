extends SceneTree

## One-off utility: regenerates EVERY skillset fixture in
## res://database/skillsets/fixtures/, superseding import_skill_panels.gd's
## own panel-writing step (which only wrote fixtures for the 220 of 384
## skillsets referenced by at least one monster's own curated
## AvailableSkillsets column -- the other 164, including Uber Breath, were
## silently never generated at all, even though "any monster can invest in
## any skillset" has been true since the universal-skillset-access change).
## Does NOT touch monster fixtures (starting_skill_ids/available_skill_sets
## stay exactly as import_skill_panels.gd already left them).
##
## Also fixes a second, unrelated gap in the same data: a threshold whose
## name matches neither a known ability NOR a stat-boost code was
## previously dropped silently ("passive perk/ward/trait... omitted"). Cross-
## referencing every real trait's own display_name shows every one of those
## dropped names is actually a real trait (e.g. Diamond Slime's own 120/150
## SP thresholds are Steady Recovery/Magic Regenerator -- HP/MP regen, not
## abilities at all) -- these are now written as "kind": "trait" thresholds.
## Confirmed zero remaining unmatched names across all 3,533 threshold
## entries once stat_boost/ability/trait are all checked.
##
## Run via: godot --headless --script res://tests/tools/import_skillsets_full.gd

const SCRATCH := "C:/Users/elivo/AppData/Local/Temp/claude/D--Dragon-Quest-Monster-Showdown/33389280-0d18-448d-bdab-bc0185796eb1/scratchpad"
const SKILLSETS_FIXTURES_DIR := "res://database/skillsets/fixtures"
const TRAITS_FIXTURES_DIR := "res://database/traits_defs"

const STAT_BOOST_REGEX := "^([A-Z]{2,4})\\s*\\+\\s*(\\d+)$"
const STAT_CODE_MAP := {"ATK": "attack", "DEF": "defense", "AGI": "agility", "WIS": "wisdom", "HP": "hp", "MP": "mp"}

var _stat_boost_re: RegEx

func _initialize() -> void:
	_stat_boost_re = RegEx.new()
	_stat_boost_re.compile(STAT_BOOST_REGEX)

	var abilities: Array = _load_json(SCRATCH + "/abilities.json")
	var skillsets: Array = _load_json(SCRATCH + "/skillsets.json")

	var ability_names := {}
	for a in abilities:
		ability_names[a["English"]] = true

	# display_name -> real trait id (read from the fixtures themselves, not
	# re-slugified, so this can never drift from what TraitDatabase actually
	# resolves).
	var trait_id_by_name := {}
	var dir := DirAccess.open(TRAITS_FIXTURES_DIR)
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var data := _load_json_dict(TRAITS_FIXTURES_DIR + "/" + file_name)
				if data.has("display_name") and data.has("id"):
					trait_id_by_name[data["display_name"]] = data["id"]
			file_name = dir.get_next()
		dir.list_dir_end()

	var skillsets_written := 0
	var skill_count := 0
	var trait_count := 0
	var stat_boost_count := 0
	var unmatched := {}
	for s in skillsets:
		var name: String = s["English"]
		var id := _slugify(name)
		var thresholds := _build_thresholds(s["Moves"], ability_names, trait_id_by_name, unmatched)
		for t in thresholds:
			if t["kind"] == "skill":
				skill_count += 1
			elif t["kind"] == "trait":
				trait_count += 1
			else:
				stat_boost_count += 1
		_write_json(SKILLSETS_FIXTURES_DIR + "/" + id + ".json", {
			"id": id,
			"display_name": name,
			"thresholds": thresholds,
		})
		skillsets_written += 1

	print("Skillset fixtures written: %d (was 220)" % skillsets_written)
	print("Threshold breakdown -- skill: %d, trait: %d, stat_boost: %d" % [skill_count, trait_count, stat_boost_count])
	print("Unmatched names (%d):" % unmatched.size())
	for n in unmatched:
		print("  ", n)
	quit(0)

func _build_thresholds(moves: Array, ability_names: Dictionary, trait_id_by_name: Dictionary, unmatched: Dictionary) -> Array:
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
		elif trait_id_by_name.has(name):
			thresholds.append({"sp": sp, "kind": "trait", "trait_id": trait_id_by_name[name]})
		else:
			unmatched[name] = true
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

func _load_json_dict(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data

func _write_json(path: String, data: Dictionary) -> void:
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_string(JSON.stringify(data, "\t"))
	out.close()
