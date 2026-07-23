extends SceneTree

## One-off utility: merges per-monster resistance data (parsed from the
## source spreadsheet's "Base Resistances" columns) into each fixture's
## "resistances" field. Run via:
## godot --headless --script res://tests/tools/merge_resistances.gd

const SCRATCH := "C:/Users/elivo/AppData/Local/Temp/claude/D--Dragon-Quest-Monster-Showdown/33389280-0d18-448d-bdab-bc0185796eb1/scratchpad"
const RESIST_CODES := ["Frz","Siz","Bng","Wsh","Crk","Rbl","Zap","Zam","Dnk","Fre","Ice","Wck","Psn","Crs","Imm","Cnf","Par","Slp","Dzl","DrM","Hck","Fzl","Blt","Abi","Gbs","Ban","Sag","Sap","Dec","Dim"]

func _initialize() -> void:
	var no_to_id := _load_no_to_id(SCRATCH + "/no_id_fixed.tsv")
	print("No->id entries: ", no_to_id.size())

	var resist_rows := _load_json_array(SCRATCH + "/resistances.json")
	print("Resistance rows: ", resist_rows.size())

	var fixtures_dir := "res://database/monsters/fixtures"
	var updated := 0
	var skipped_no_fixture: Array[String] = []

	for row in resist_rows:
		var no: String = row.get("No", "")
		if not no_to_id.has(no):
			continue
		var id: String = no_to_id[no]
		var path := fixtures_dir + "/" + id + ".json"
		if not FileAccess.file_exists(path):
			skipped_no_fixture.append(id)
			continue

		var sparse := {}
		for code in RESIST_CODES:
			var val: String = row.get(code, "")
			if val != "":
				sparse[code] = val

		var f := FileAccess.open(path, FileAccess.READ)
		var text := f.get_as_text()
		f.close()
		var json := JSON.new()
		if json.parse(text) != OK:
			print("PARSE ERROR: ", path)
			continue
		var data: Dictionary = json.data
		data["resistances"] = sparse

		var out := FileAccess.open(path, FileAccess.WRITE)
		out.store_string(JSON.stringify(data, "\t"))
		out.close()
		updated += 1

	print("Fixtures updated: ", updated)
	print("Rows with no matching fixture: ", skipped_no_fixture.size())
	for id in skipped_no_fixture:
		print("  ", id)
	quit(0)

func _load_no_to_id(path: String) -> Dictionary:
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

func _load_json_array(path: String) -> Array:
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
