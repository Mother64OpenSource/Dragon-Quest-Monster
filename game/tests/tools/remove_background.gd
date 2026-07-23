extends SceneTree

## One-off utility: flood-fills a uniform background color to transparent,
## starting from the border pixels inward (so it never eats into similarly
## colored regions inside the subject that aren't connected to the edge).
## Converts the result to PNG (jpg can't hold alpha).
##
## Run via: godot --headless --script res://tests/tools/remove_background.gd

const TARGET_IDS: Array[String] = [
	"argo", "dark_crystal", "gold_ninja_slime", "hammibal", "king_godfrey",
	"maizar", "silver_ninja_slime", "numen", "holy_dragon_miraclea", "leida_metes_temple"
]
const COLOR_TOLERANCE := 0.06

func _initialize() -> void:
	var assets_dir := "res://assets/monsters"
	for id in TARGET_IDS:
		var path := _find_existing_path(assets_dir, id)
		if path.is_empty():
			print("SKIP (not found): %s" % id)
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null:
			print("FAIL to load: %s" % path)
			continue
		image.convert(Image.FORMAT_RGBA8)
		_flood_fill_transparent(image)

		var new_path: String = assets_dir + "/" + id + ".png"
		var err := image.save_png(ProjectSettings.globalize_path(new_path))
		if err != OK:
			print("FAIL to save: %s (err %d)" % [new_path, err])
			continue

		# Remove the old non-png source file if the extension changed.
		var old_global := ProjectSettings.globalize_path(path)
		var new_global := ProjectSettings.globalize_path(new_path)
		if old_global != new_global:
			DirAccess.remove_absolute(old_global)
		print("OK: %s -> %s.png" % [id, id])
	quit(0)

func _find_existing_path(dir_path: String, id: String) -> String:
	for ext in ["webp", "png", "jpg", "jpeg"]:
		var candidate := "%s/%s.%s" % [dir_path, id, ext]
		if FileAccess.file_exists(candidate):
			return candidate
	return ""

func _flood_fill_transparent(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	if w == 0 or h == 0:
		return

	var bg := image.get_pixel(0, 0)
	var visited := PackedByteArray()
	visited.resize(w * h)

	var stack: Array[Vector2i] = []
	for x in range(w):
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in range(h):
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))

	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.x >= w or p.y < 0 or p.y >= h:
			continue
		var idx := p.y * w + p.x
		if visited[idx] == 1:
			continue
		var color := image.get_pixel(p.x, p.y)
		if _color_distance(color, bg) > COLOR_TOLERANCE:
			continue
		visited[idx] = 1
		image.set_pixel(p.x, p.y, Color(color.r, color.g, color.b, 0.0))
		stack.append(Vector2i(p.x + 1, p.y))
		stack.append(Vector2i(p.x - 1, p.y))
		stack.append(Vector2i(p.x, p.y + 1))
		stack.append(Vector2i(p.x, p.y - 1))

func _color_distance(a: Color, b: Color) -> float:
	return max(absf(a.r - b.r), max(absf(a.g - b.g), absf(a.b - b.b)))
