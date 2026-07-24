extends SceneTree

## One-off utility: adds real move-description text (scraped from the
## project's Google Sheets action list) to every matching skill fixture, for
## hover-tooltip display in the team builder and battle UI. Matches by exact
## display_name -> CSV "English" column text -- fixture ids/display_names
## were never derived from this particular sheet tab, so slugified-id
## matching isn't reliable; the human-readable names line up directly
## instead. See wiki/log.md.
##
## Run via: godot --headless --script res://tests/tools/import_skill_descriptions.gd

const SCRATCH := "C:/Users/elivo/AppData/Local/Temp/claude/D--Dragon-Quest-Monster-Showdown/33389280-0d18-448d-bdab-bc0185796eb1/scratchpad"
const CSV_PATH := SCRATCH + "/actions_with_descriptions.csv"
const SKILL_FIXTURES_DIR := "res://database/skills/fixtures"

func _initialize() -> void:
	var rows := _parse_csv(CSV_PATH)
	print("Parsed %d CSV rows" % rows.size())

	var descriptions := {}  # English name (as in sheet) -> cleaned description text
	for row in rows.slice(1):  # skip header row
		if row.size() < 4:
			continue
		var english: String = row[2].strip_edges()
		var raw_description: String = row[3]
		if english.is_empty() or raw_description.strip_edges().is_empty():
			continue
		var cleaned := raw_description.replace("\n", " ")
		while cleaned.contains("  "):
			cleaned = cleaned.replace("  ", " ")
		descriptions[english] = cleaned.strip_edges()

	print("Collected %d named descriptions" % descriptions.size())

	var dir := DirAccess.open(SKILL_FIXTURES_DIR)
	if dir == null:
		print("Cannot open fixtures dir")
		quit(1)
		return

	var matched := 0
	var unmatched: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var path := SKILL_FIXTURES_DIR + "/" + file_name
			var f := FileAccess.open(path, FileAccess.READ)
			var text := f.get_as_text()
			f.close()
			var json := JSON.new()
			if json.parse(text) != OK:
				print("PARSE ERROR: ", path)
				file_name = dir.get_next()
				continue
			var data: Dictionary = json.data
			var display_name: String = data.get("display_name", "")
			if descriptions.has(display_name):
				data["description"] = descriptions[display_name]
				var out := FileAccess.open(path, FileAccess.WRITE)
				out.store_string(JSON.stringify(data, "\t"))
				out.close()
				matched += 1
			else:
				unmatched.append(display_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("Matched and updated: %d" % matched)
	print("Unmatched (%d):" % unmatched.size())
	for name in unmatched:
		print("  ", name)
	quit(0)

## Manual state-machine CSV parser -- Godot's built-in
## FileAccess.get_csv_line() reads one physical line at a time and does not
## merge quoted fields that span multiple physical lines, which this sheet's
## Description column does throughout. Handles doubled "" as an escaped quote.
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
