extends SceneTree

## One-off utility: imports real per-monster movesets from the source
## spreadsheet. See wiki/log.md for the full rationale and the documented
## categorization heuristic (this only infers a *generic* battle effect per
## move from its Type/Attribute/Range -- exact behavior/balance matching the
## original game is explicitly out of scope, same deferral as the damage
## formula work).
##
## Run via: godot --headless --script res://tests/tools/import_movesets.gd

const SCRATCH := "C:/Users/elivo/AppData/Local/Temp/claude/D--Dragon-Quest-Monster-Showdown/33389280-0d18-448d-bdab-bc0185796eb1/scratchpad"
const SKILLS_FIXTURES_DIR := "res://database/skills/fixtures"
const STATUS_FIXTURES_DIR := "res://database/status_defs"
const MONSTER_FIXTURES_DIR := "res://database/monsters/fixtures"

const STATUS_ATTRS := ["Poison", "Sleep", "Paralysis", "Confusion", "Curse", "Dazzle", "Silence", "Gobstop", "Immobilize"]
const STAT_DOWN_MAP := {"Sap": "defense", "Sag": "attack", "Decelerate": "agility"}
const STAT_BOOST_REGEX := "^[A-Z]{2,4}\\s*\\+\\s*\\d+$"

var _stat_boost_re: RegEx
var _new_skill_count := 0
var _new_status_count := 0
var _monsters_updated := 0
var _unresolved_names: Dictionary = {}

func _initialize() -> void:
	_stat_boost_re = RegEx.new()
	_stat_boost_re.compile(STAT_BOOST_REGEX)

	var abilities: Array = _load_json(SCRATCH + "/abilities.json")
	var skillsets: Array = _load_json(SCRATCH + "/skillsets.json")
	var monster_skillsets: Array = _load_json(SCRATCH + "/monster_skillset.json")
	var no_to_id := _load_tsv(SCRATCH + "/no_id_fixed.tsv")

	print("Loaded: %d abilities, %d skillsets, %d monster-skillset rows, %d no->id" % [
		abilities.size(), skillsets.size(), monster_skillsets.size(), no_to_id.size()
	])

	var ability_by_name := {}
	for a in abilities:
		ability_by_name[a["English"]] = a

	var moves_by_skillset := {}
	for s in skillsets:
		var names: Array[String] = []
		for m in s["Moves"]:
			var name: String = m["name"]
			if _stat_boost_re.search(name) != null:
				continue
			if not names.has(name):
				names.append(name)
		moves_by_skillset[s["English"]] = names

	var skillset_by_no := {}
	for row in monster_skillsets:
		skillset_by_no[row["No"]] = row["Skill"]

	# Existing status ids already on disk (poison) -- never overwrite.
	var existing_status_ids := {}
	var sdir := DirAccess.open(STATUS_FIXTURES_DIR)
	if sdir:
		sdir.list_dir_begin()
		var fname := sdir.get_next()
		while fname != "":
			if fname.ends_with(".json"):
				existing_status_ids[fname.get_basename()] = true
			fname = sdir.get_next()
		sdir.list_dir_end()

	# Existing skill ids already on disk -- never overwrite (preserves the
	# Milestone 1 hand-tuned attack/frizz/heal/oomph/sap/double_slash/poison_breath).
	var existing_skill_ids := {}
	var kdir := DirAccess.open(SKILLS_FIXTURES_DIR)
	if kdir:
		kdir.list_dir_begin()
		var fname2 := kdir.get_next()
		while fname2 != "":
			if fname2.ends_with(".json"):
				existing_skill_ids[fname2.get_basename()] = true
			fname2 = kdir.get_next()
		kdir.list_dir_end()

	# Build/write every ability referenced by at least one monster skillset.
	var referenced_names := {}
	for skillset_name in moves_by_skillset:
		for name in moves_by_skillset[skillset_name]:
			referenced_names[name] = true

	for name in referenced_names:
		if not ability_by_name.has(name):
			_unresolved_names[name] = true
			continue
		var id := _slugify(name)
		if existing_skill_ids.has(id):
			continue
		var ability: Dictionary = ability_by_name[name]
		var skill_json := _build_skill_json(id, name, ability, existing_status_ids)
		_write_json(SKILLS_FIXTURES_DIR + "/" + id + ".json", skill_json)
		existing_skill_ids[id] = true
		_new_skill_count += 1

	# Now update every monster fixture's starting_skill_ids.
	for no in skillset_by_no:
		if not no_to_id.has(no):
			continue
		var monster_id: String = no_to_id[no]
		var path := MONSTER_FIXTURES_DIR + "/" + monster_id + ".json"
		if not FileAccess.file_exists(path):
			continue
		var skillset_name: String = skillset_by_no[no]
		var move_names: Array = moves_by_skillset.get(skillset_name, [])

		var skill_ids: Array[String] = ["attack"]
		for name in move_names:
			if not ability_by_name.has(name):
				continue
			var id := _slugify(name)
			if not skill_ids.has(id):
				skill_ids.append(id)

		var f := FileAccess.open(path, FileAccess.READ)
		var text := f.get_as_text()
		f.close()
		var json := JSON.new()
		if json.parse(text) != OK:
			print("PARSE ERROR: ", path)
			continue
		var data: Dictionary = json.data
		data["starting_skill_ids"] = skill_ids
		_write_json(path, data)
		_monsters_updated += 1

	print("New skill fixtures created: ", _new_skill_count)
	print("New status fixtures created: ", _new_status_count)
	print("Monsters updated: ", _monsters_updated)
	print("Move names with no ability match (excluded, likely passive perks/wards/traits): ", _unresolved_names.size())
	quit(0)

func _build_skill_json(id: String, display_name: String, ability: Dictionary, existing_status_ids: Dictionary) -> Dictionary:
	var mp: int = int(ability.get("MP", "0")) if (ability.get("MP", "") as String).is_valid_int() else 0
	var type: String = ability.get("Type", "")
	var attribute: String = ability.get("Attribute", "")
	var range_val: String = ability.get("Range", "")

	var self_targeted := range_val in ["Self", "Single Ally", "All Allies", "Everyone"]
	var target_type := "self" if self_targeted else "single_enemy"

	var category := ""
	var effects: Array = []

	if attribute in STATUS_ATTRS:
		var status_id := _slugify(attribute)
		if not existing_status_ids.has(status_id):
			_write_status_fixture(status_id, attribute)
			existing_status_ids[status_id] = true
			_new_status_count += 1
		category = "status"
		effects = [{"type": "status", "status_id": status_id, "chance": 0.5, "target_self": self_targeted}]
	elif display_name.to_lower().contains("heal"):
		category = "status"
		effects = [{"type": "heal", "power": 15 + mp * 8, "target_self": true}]
	elif STAT_DOWN_MAP.has(attribute):
		category = "status"
		effects = [{"type": "stat_mod", "stat_name": STAT_DOWN_MAP[attribute], "stages": -1, "target_self": false}]
	elif type == "Dance":
		category = "status"
		effects = [{"type": "stat_mod", "stat_name": _guess_buff_stat(display_name), "stages": 1, "target_self": true}]
	else:
		category = "magic" if type == "Spell" else "physical"
		var power := 15 + int(round(mp * 3.0))
		effects = [{"type": "damage", "category": category, "power": power}]

	return {
		"id": id,
		"display_name": display_name,
		"mp_cost": mp,
		"priority": 0,
		"accuracy": 1.0,
		"category": category,
		"target_type": target_type,
		"effects": effects,
	}

func _guess_buff_stat(name: String) -> String:
	var lower := name.to_lower()
	if lower.contains("guard") or lower.contains("protect") or lower.contains("iron") or lower.contains("steel"):
		return "defense"
	if lower.contains("quick") or lower.contains("fast") or lower.contains("haste") or lower.contains("accelerat") or lower.contains("speed"):
		return "agility"
	if lower.contains("wisdom") or lower.contains("wise") or lower.contains("mage") or lower.contains("magic"):
		return "wisdom"
	return "attack"

func _write_status_fixture(status_id: String, attribute: String) -> void:
	var data := {
		"id": status_id,
		"display_name": attribute,
		"tick_damage_percent": 0.0,
		"skip_turn_chance": 0.0,
		"duration_turns": 3,
		"stat_mods_on_apply": [],
	}
	match status_id:
		"sleep":
			data["skip_turn_chance"] = 0.8
		"paralysis":
			data["skip_turn_chance"] = 0.5
			data["duration_turns"] = 4
		"confusion":
			data["skip_turn_chance"] = 0.33
		"curse":
			data["stat_mods_on_apply"] = [{"stat_name": "attack", "stages": -1, "chance": 1.0, "target_self": true}]
			data["duration_turns"] = 5
		"dazzle":
			data["stat_mods_on_apply"] = [{"stat_name": "agility", "stages": -1, "chance": 1.0, "target_self": true}]
		"silence":
			data["skip_turn_chance"] = 0.3
		"gobstop":
			data["skip_turn_chance"] = 0.3
		"immobilize":
			data["stat_mods_on_apply"] = [{"stat_name": "agility", "stages": -2, "chance": 1.0, "target_self": true}]
	_write_json(STATUS_FIXTURES_DIR + "/" + status_id + ".json", data)

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
