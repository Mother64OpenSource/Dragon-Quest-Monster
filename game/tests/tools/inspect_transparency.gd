extends SceneTree

## One-off utility: reports which images in game/assets/monsters/ lack a
## transparent background (no alpha channel, or corner pixels are opaque).
## Run via: godot --headless --script res://tests/tools/inspect_transparency.gd
func _initialize() -> void:
	var dir := DirAccess.open("res://assets/monsters")
	if dir == null:
		print("Cannot open assets/monsters")
		quit(1)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var opaque_files: Array[String] = []
	var transparent_files: Array[String] = []
	var failed_files: Array[String] = []

	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".webp") or file_name.ends_with(".png") or file_name.ends_with(".jpg") or file_name.ends_with(".jpeg")):
			var path := "res://assets/monsters/" + file_name
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			if image == null:
				failed_files.append(file_name)
			else:
				if _has_transparent_background(image):
					transparent_files.append(file_name)
				else:
					opaque_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("=== TRANSPARENT (%d) ===" % transparent_files.size())
	print("=== OPAQUE/NO ALPHA (%d) ===" % opaque_files.size())
	for f in opaque_files:
		print(f)
	print("=== FAILED TO LOAD (%d) ===" % failed_files.size())
	for f in failed_files:
		print(f)
	quit(0)

## Heuristic: no alpha channel at all -> opaque. Otherwise, sample the 4
## corners; if all 4 are fully opaque (alpha ~255) treat as "no transparent
## background" even though the format supports alpha (i.e. a flat-filled
## PNG/webp with no cutout).
func _has_transparent_background(image: Image) -> bool:
	if not image.detect_alpha() and image.get_format() != Image.FORMAT_RGBA8:
		pass # fall through to pixel sampling regardless of detect_alpha's own heuristic
	var w := image.get_width()
	var h := image.get_height()
	if w == 0 or h == 0:
		return false
	var corners := [
		Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)
	]
	for c in corners:
		var pixel := image.get_pixel(c.x, c.y)
		if pixel.a < 0.95:
			return true
	return false
