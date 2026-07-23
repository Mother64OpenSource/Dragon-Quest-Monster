extends SceneTree

func _initialize() -> void:
	var assets_dir := "res://assets/monsters"
	var fixtures_dir := "res://database/monsters/fixtures"

	var id_to_filename: Dictionary = {}
	var dir := DirAccess.open(assets_dir)
	if dir:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and not fname.ends_with(".import"):
				var stem := fname.get_basename()
				id_to_filename[stem] = fname
			fname = dir.get_next()
		dir.list_dir_end()

	var fixtures := DirAccess.open(fixtures_dir)
	var set_count := 0
	var removed_count := 0
	var unchanged_count := 0
	var total := 0

	fixtures.list_dir_begin()
	var fname2 := fixtures.get_next()
	while fname2 != "":
		if fname2.ends_with(".json"):
			total += 1
			var path := fixtures_dir + "/" + fname2
			var f := FileAccess.open(path, FileAccess.READ)
			var text := f.get_as_text()
			f.close()

			var json := JSON.new()
			var err := json.parse(text)
			if err != OK:
				print("PARSE ERROR: ", fname2)
				fname2 = fixtures.get_next()
				continue

			var data: Dictionary = json.data
			var id: String = data.get("id", "")
			var had_sprite: bool = data.has("sprite_path")
			var new_path := ""
			if id_to_filename.has(id):
				new_path = assets_dir + "/" + id_to_filename[id]

			var changed := false
			if new_path != "":
				if not had_sprite or data["sprite_path"] != new_path:
					data["sprite_path"] = new_path
					changed = true
					set_count += 1
				else:
					unchanged_count += 1
			else:
				if had_sprite:
					data.erase("sprite_path")
					changed = true
					removed_count += 1
				else:
					unchanged_count += 1

			if changed:
				var out := FileAccess.open(path, FileAccess.WRITE)
				out.store_string(JSON.stringify(data, "\t"))
				out.close()

		fname2 = fixtures.get_next()
	fixtures.list_dir_end()

	print("Total fixtures: ", total)
	print("sprite_path set/corrected: ", set_count)
	print("sprite_path removed: ", removed_count)
	print("unchanged: ", unchanged_count)
	quit()
