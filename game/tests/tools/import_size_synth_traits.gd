extends SceneTree

## One-off utility: populates size_gated_trait_ids/synth_gated_trait_ids on
## every monster fixture from the same per-monster "Traits" cell
## import_traits.gd already reads for the unconditional "By Default" tier
## (sheet1.csv row[16]) -- that cell is actually 3 newline-separated lines
## per monster (By Default / If Size [P/H/G] / If Rank Offset
## [+25/+50/+★]), of which only line 1 was ever imported. This reads lines
## 2 and 3.
##
## Deliberately does NOT assume line 2 is always "If Size" and line 3 is
## always "If Rank Offset" -- one monster (Togrus Maximus) only has 2 lines
## total (no Size-tier data at all), so each line after the first is
## classified by which tag vocabulary it actually contains ([P]/[H]/[G] vs
## [+25]/[+50]/[+★]) rather than by position.
##
## Run via: godot --headless --script res://tests/tools/import_size_synth_traits.gd

const SCRATCH := "C:/Users/elivo/AppData/Local/Temp/claude/D--Dragon-Quest-Monster-Showdown/33389280-0d18-448d-bdab-bc0185796eb1/scratchpad"
const MONSTERS_CSV := SCRATCH + "/sheet1.csv"
const TRAITS_FIXTURES_DIR := "res://database/traits_defs"
const MONSTER_FIXTURES_DIR := "res://database/monsters/fixtures"

const SIZE_TAGS := ["P", "H", "G"]
const SYNTH_TAG_MAP := {"+25": "25", "+50": "50", "+★": "star"}

func _initialize() -> void:
	var no_to_id := _load_tsv(SCRATCH + "/no_id_fixed.tsv")

	# Cross-check every parsed trait name against the trait fixtures that
	# already exist (built by import_traits.gd from the same source data),
	# so a slugify mismatch shows up as a loud miss instead of silently
	# writing a dangling id nothing resolves.
	var known_trait_ids := {}
	var dir := DirAccess.open(TRAITS_FIXTURES_DIR)
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				known_trait_ids[file_name.trim_suffix(".json")] = true
			file_name = dir.get_next()
		dir.list_dir_end()

	var monster_rows := _parse_csv(MONSTERS_CSV)
	var monsters_updated := 0
	var size_assignments := 0
	var synth_assignments := 0
	var unmatched_names := {}

	for row in monster_rows.slice(2):
		if row.size() < 17:
			continue
		var no: String = row[0].strip_edges()
		if no.is_empty() or not no_to_id.has(no):
			continue
		var monster_id: String = no_to_id[no]
		var path := MONSTER_FIXTURES_DIR + "/" + monster_id + ".json"
		if not FileAccess.file_exists(path):
			continue

		var lines: PackedStringArray = row[16].split("\n")
		var size_gated := {}
		var synth_gated := {}
		for li in range(1, lines.size()):
			var line := lines[li].strip_edges()
			if line.is_empty():
				continue
			for part in line.split(" - "):
				var entry := part.strip_edges()
				if entry.is_empty() or not entry.ends_with("]"):
					continue
				var bracket_start := entry.rfind("[")
				if bracket_start == -1:
					continue
				var trait_name := entry.substr(0, bracket_start).strip_edges()
				var tag := entry.substr(bracket_start + 1, entry.length() - bracket_start - 2)
				var trait_id := _slugify(trait_name)
				if not known_trait_ids.has(trait_id):
					unmatched_names[trait_name] = true
					continue
				if SIZE_TAGS.has(tag):
					if not size_gated.has(tag):
						size_gated[tag] = []
					size_gated[tag].append(trait_id)
					size_assignments += 1
				elif SYNTH_TAG_MAP.has(tag):
					var bucket: String = SYNTH_TAG_MAP[tag]
					if not synth_gated.has(bucket):
						synth_gated[bucket] = []
					synth_gated[bucket].append(trait_id)
					synth_assignments += 1

		var f := FileAccess.open(path, FileAccess.READ)
		var text := f.get_as_text()
		f.close()
		var json := JSON.new()
		if json.parse(text) != OK:
			print("PARSE ERROR: ", path)
			continue
		var data: Dictionary = json.data
		data["size_gated_trait_ids"] = size_gated
		data["synth_gated_trait_ids"] = synth_gated
		_write_json(path, data)
		monsters_updated += 1

	print("Monsters updated: %d" % monsters_updated)
	print("Size-tier trait assignments: %d" % size_assignments)
	print("Rank-offset trait assignments: %d" % synth_assignments)
	print("Unmatched trait names (%d):" % unmatched_names.size())
	for name in unmatched_names:
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

## Manual state-machine CSV parser -- same as import_traits.gd's own (see
## its doc comment for why FileAccess.get_csv_line() doesn't work here).
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
