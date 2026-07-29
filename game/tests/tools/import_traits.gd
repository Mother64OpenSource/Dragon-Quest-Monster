extends SceneTree

## One-off utility: builds TraitData fixtures for every real trait name in
## the project's Google Sheets "Traits" reference tab, then populates every
## monster fixture's starting_trait_ids from that same sheet's per-monster
## "Traits" column ("By Default" tier only -- the sheet's per-monster Traits
## cell also lists Size-tier and Rank-offset-tier traits on two further
## lines; see import_size_synth_traits.gd, which imports those into
## size_gated_trait_ids/synth_gated_trait_ids once this script has already
## populated the trait fixtures it depends on). See wiki/log.md.
##
## Run via: godot --headless --script res://tests/tools/import_traits.gd

const SCRATCH := "C:/Users/elivo/AppData/Local/Temp/claude/D--Dragon-Quest-Monster-Showdown/33389280-0d18-448d-bdab-bc0185796eb1/scratchpad"
const TRAITS_CSV := SCRATCH + "/traits_sheet.csv"
const MONSTERS_CSV := SCRATCH + "/sheet1.csv"
const TRAITS_FIXTURES_DIR := "res://database/traits_defs"
const MONSTER_FIXTURES_DIR := "res://database/monsters/fixtures"

## Rows like "HP +2" / "WIS +40" are skillset SP-threshold stat boosts that
## happen to share the Traits sheet's numbering, not real innate monster
## traits (their own "By Default" monster column is always None) -- same
## exclusion this project already applied when importing skillset panels.
const STAT_BOOST_REGEX := "^([A-Z]{2,4})\\s*\\+\\s*(\\d+)$"

var _stat_boost_re: RegEx

func _initialize() -> void:
	_stat_boost_re = RegEx.new()
	_stat_boost_re.compile(STAT_BOOST_REGEX)

	var no_to_id := _load_tsv(SCRATCH + "/no_id_fixed.tsv")

	var trait_rows := _parse_csv(TRAITS_CSV)
	var traits_by_name := {}  # English name -> {id, display_name, description}
	var excluded := 0
	for row in trait_rows.slice(3):  # skip the two header rows + "Trait" marker row
		if row.size() < 4:
			continue
		var english: String = row[2].strip_edges()
		if english.is_empty():
			continue
		if _stat_boost_re.search(english) != null:
			excluded += 1
			continue
		var cleaned_desc: String = row[3].replace("\n", " ").replace("／", "/")
		while cleaned_desc.contains("  "):
			cleaned_desc = cleaned_desc.replace("  ", " ")
		cleaned_desc = cleaned_desc.strip_edges()
		var id := _slugify(english)
		traits_by_name[english] = {"id": id, "display_name": english, "description": cleaned_desc}

	print("Trait rows parsed: %d | unique real traits: %d | excluded stat-boost rows: %d" % [trait_rows.size() - 3, traits_by_name.size(), excluded])

	var fixtures_written := 0
	for name in traits_by_name:
		var t: Dictionary = traits_by_name[name]
		_write_json(TRAITS_FIXTURES_DIR + "/" + t["id"] + ".json", {
			"id": t["id"],
			"display_name": t["display_name"],
			"description": t["description"],
		})
		fixtures_written += 1
	print("Trait fixtures written: %d" % fixtures_written)

	var monster_rows := _parse_csv(MONSTERS_CSV)
	var monsters_updated := 0
	var no_mapping_misses := 0
	var unmatched_trait_names := {}
	var total_trait_assignments := 0
	for row in monster_rows.slice(2):  # skip the two header rows
		if row.size() < 17:
			continue
		var no: String = row[0].strip_edges()
		if no.is_empty() or not no_to_id.has(no):
			if not no.is_empty():
				no_mapping_misses += 1
			continue
		var monster_id: String = no_to_id[no]
		var path := MONSTER_FIXTURES_DIR + "/" + monster_id + ".json"
		if not FileAccess.file_exists(path):
			continue

		var lines: PackedStringArray = row[16].split("\n")
		var default_line := lines[0].strip_edges() if lines.size() > 0 else ""
		var trait_ids: Array = []
		if not default_line.is_empty() and default_line != "None":
			for part in default_line.split(" - "):
				var trait_name := part.strip_edges()
				if trait_name.is_empty():
					continue
				if traits_by_name.has(trait_name):
					trait_ids.append(traits_by_name[trait_name]["id"])
					total_trait_assignments += 1
				else:
					unmatched_trait_names[trait_name] = true

		var f := FileAccess.open(path, FileAccess.READ)
		var text := f.get_as_text()
		f.close()
		var json := JSON.new()
		if json.parse(text) != OK:
			print("PARSE ERROR: ", path)
			continue
		var data: Dictionary = json.data
		data["starting_trait_ids"] = trait_ids
		_write_json(path, data)
		monsters_updated += 1

	print("Monsters updated: %d" % monsters_updated)
	print("Monsters with no No.->id mapping: %d" % no_mapping_misses)
	print("Total trait assignments: %d" % total_trait_assignments)
	print("Unmatched trait names (%d):" % unmatched_trait_names.size())
	for name in unmatched_trait_names:
		print("  ", name)
	quit(0)

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

## Manual state-machine CSV parser -- Godot's built-in FileAccess.get_csv_line()
## reads one physical line at a time and does not merge quoted fields that
## span multiple physical lines, which both these sheets' cells do throughout
## (Description columns, and every monster's 3-line Traits cell). Handles
## doubled "" as an escaped quote.
func _parse_csv(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		print("Cannot open: ", path)
		return []
	var text := f.get_as_text()
	f.close()

	var rows: Array = []
	var row: Array = []
	var field := ""
	var in_quotes := false
	var i := 0
	var length := text.length()
	while i < length:
		var c := text[i]
		if in_quotes:
			if c == "\"":
				if i + 1 < length and text[i + 1] == "\"":
					field += "\""
					i += 1
				else:
					in_quotes = false
			else:
				field += c
		else:
			if c == "\"":
				in_quotes = true
			elif c == ",":
				row.append(field)
				field = ""
			elif c == "\r":
				pass
			elif c == "\n":
				row.append(field)
				rows.append(row)
				row = []
				field = ""
			else:
				field += c
		i += 1
	if not field.is_empty() or not row.is_empty():
		row.append(field)
		rows.append(row)
	return rows
