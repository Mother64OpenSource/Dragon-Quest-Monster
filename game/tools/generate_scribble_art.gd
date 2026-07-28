extends SceneTree

## Batch-generates a deliberately terrible "MS Paint mouse scribble"
## placeholder image for every monster species, as an alternate,
## opt-in art style (see ArtStylePreferenceManager / the "Use Hand-
## Drawn Art" checkbox). Saved alongside the real artwork, never
## overwriting or deleting it.
##
## Deliberately does NOT trace, approximate, or otherwise derive each
## drawing's actual shape from the source artwork -- only two
## non-expressive, purely statistical facts are sampled from the
## original image (its average color over non-transparent pixels, and
## its rough width/height aspect ratio), and those two numbers just
## seed a genuinely randomized wobbly blob. The shape, "face," and
## every stray scribble line are procedural noise, not a copy of
## anything. Re-running this script reproduces byte-identical output
## per species (seeded by a hash of species_id), so the "bad drawing"
## for a given monster doesn't change between runs.
##
## Usage: godot --headless --script res://tools/generate_scribble_art.gd
##   --user-data-dir "D:/godot_user_data" --path . [-- --limit N]
## --limit caps how many species to process, for a quick preview batch
## before committing to the full ~800-monster run.

const FIXTURES_DIR := "res://database/monsters/fixtures"
const OUTPUT_DIR := "res://assets/monsters_scribble"
const CANVAS_SIZE := 40          # low-res working canvas -- the whole
                                  # point of the blocky look
const FINAL_SIZE := 160          # nearest-neighbor upscale target
const ANGLE_STEPS := 20          # blob outline control points

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var limit := -1
	var limit_idx := args.find("--limit")
	if limit_idx != -1 and limit_idx + 1 < args.size():
		limit = int(args[limit_idx + 1])

	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)

	var species_ids := JsonDirLoader.list_json_files(FIXTURES_DIR)
	var processed := 0
	var skipped := 0
	for path in species_ids:
		if limit >= 0 and processed >= limit:
			break
		var species := MonsterLoader.load_from_file(path)
		if species == null or species.sprite_path.is_empty():
			skipped += 1
			continue
		var ok := _generate_one(species)
		if ok:
			processed += 1
		else:
			skipped += 1

	print("Scribble art generated for %d species (%d skipped)." % [processed, skipped])
	quit()

func _generate_one(species: MonsterSpecies) -> bool:
	var texture: Texture2D = load(species.sprite_path)
	if texture == null:
		push_warning("Couldn't load source image for %s: %s" % [species.id, species.sprite_path])
		return false
	var source_image := texture.get_image()
	if source_image == null:
		return false

	var avg_color := _average_color(source_image)
	var aspect := float(source_image.get_width()) / float(maxi(1, source_image.get_height()))

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(species.id)

	var out := _draw_scribble(avg_color, aspect, rng)
	var dest_path := "%s/%s.png" % [OUTPUT_DIR, species.id]
	var abs_dest := ProjectSettings.globalize_path(dest_path)
	var err := out.save_png(abs_dest)
	if err != OK:
		push_warning("Failed to save %s (error %d)" % [dest_path, err])
		return false
	return true

## Plain average over every non-transparent pixel -- a single aggregate
## number, not anything shape-related.
func _average_color(image: Image) -> Color:
	var img := image
	var w := img.get_width()
	var h := img.get_height()
	# Sampling a grid instead of every pixel -- plenty accurate for a
	# single averaged color, and much faster across ~800 images.
	var step_x := maxi(1, w / 24)
	var step_y := maxi(1, h / 24)
	var r := 0.0
	var g := 0.0
	var b := 0.0
	var count := 0
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var c := img.get_pixel(x, y)
			if c.a > 0.1:
				r += c.r
				g += c.g
				b += c.b
				count += 1
			x += step_x
		y += step_y
	if count == 0:
		return Color(0.5, 0.5, 0.5)
	return Color(r / count, g / count, b / count)

## The actual doodle: a jittery closed blob (radius-per-angle noise, no
## relation whatsoever to the source image's real silhouette), filled
## with a color derived from (but intentionally not identical to) the
## sampled average, plus two dot eyes, a wobbly mouth, and a couple of
## stray off-blob scribble lines for that "gave up halfway through"
## quality. Drawn at CANVAS_SIZE then upscaled with nearest-neighbor
## filtering to FINAL_SIZE for the chunky, blocky mouse-drawn look.
func _draw_scribble(avg_color: Color, aspect: float, rng: RandomNumberGenerator) -> Image:
	var small := Image.create(CANVAS_SIZE, CANVAS_SIZE, false, Image.FORMAT_RGBA8)
	small.fill(Color(1, 1, 1, 1))

	var center := Vector2(CANVAS_SIZE / 2.0, CANVAS_SIZE / 2.0 + rng.randf_range(-2, 2))
	var base_radius_x := clampf(CANVAS_SIZE * 0.32 * clampf(aspect, 0.5, 1.8), 6.0, 17.0)
	var base_radius_y := clampf(CANVAS_SIZE * 0.32 / clampf(aspect, 0.5, 1.8), 6.0, 17.0)

	# A hand-jittered blob outline, one radius sample per angle step,
	# linearly interpolated between samples so the edge is wobbly but
	# still a closed loop rather than pure per-pixel noise.
	var radii: Array[float] = []
	for i in range(ANGLE_STEPS):
		radii.append(1.0 + rng.randf_range(-0.28, 0.28))

	# A scribbled fill color -- nudged away from the sampled average
	# rather than used verbatim, so this never reproduces the source
	# image's exact palette either.
	var fill_color := Color(
		clampf(avg_color.r + rng.randf_range(-0.15, 0.15), 0.05, 0.95),
		clampf(avg_color.g + rng.randf_range(-0.15, 0.15), 0.05, 0.95),
		clampf(avg_color.b + rng.randf_range(-0.15, 0.15), 0.05, 0.95),
		1.0
	)
	var outline_color := fill_color.darkened(0.55)

	for y in range(CANVAS_SIZE):
		for x in range(CANVAS_SIZE):
			var dx: float = (x - center.x) / base_radius_x
			var dy: float = (y - center.y) / base_radius_y
			var dist := Vector2(dx, dy).length()
			var angle := fposmod(atan2(dy, dx), TAU)
			var slot := angle / TAU * ANGLE_STEPS
			var i0 := int(floor(slot)) % ANGLE_STEPS
			var i1 := (i0 + 1) % ANGLE_STEPS
			var t: float = slot - floor(slot)
			var allowed: float = lerp(radii[i0], radii[i1], t)
			if dist <= allowed:
				if dist >= allowed - 0.12:
					small.set_pixel(x, y, outline_color)
				else:
					small.set_pixel(x, y, fill_color)

	# Two dot eyes, jittered off-center and slightly mismatched in size
	# on purpose -- nothing about a real face should line up.
	_dab(small, center + Vector2(-base_radius_x * 0.35, -base_radius_y * 0.15) + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)), 1 + rng.randi_range(0, 1), Color.BLACK)
	_dab(small, center + Vector2(base_radius_x * 0.35, -base_radius_y * 0.2) + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)), 1 + rng.randi_range(0, 1), Color.BLACK)

	# A crooked mouth scribble -- a few connected jittery segments below
	# the eyes.
	var mouth_start := center + Vector2(-base_radius_x * 0.3, base_radius_y * 0.35)
	var prev := mouth_start
	for i in range(4):
		var next: Vector2 = mouth_start + Vector2(base_radius_x * 0.2 * (i + 1), rng.randf_range(-2.5, 2.5))
		_line(small, prev, next, Color.BLACK)
		prev = next

	# A couple of stray scribble lines poking outside the blob entirely
	# -- the unmistakable mark of a mouse-drawn doodle that got away
	# from whoever drew it.
	for i in range(rng.randi_range(1, 3)):
		var edge_angle := rng.randf_range(0, TAU)
		var edge_point := center + Vector2(cos(edge_angle) * base_radius_x, sin(edge_angle) * base_radius_y)
		var stray_end := edge_point + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		_line(small, edge_point, stray_end, outline_color)

	var final_image := small.duplicate() as Image
	final_image.resize(FINAL_SIZE, FINAL_SIZE, Image.INTERPOLATE_NEAREST)
	return final_image

func _dab(img: Image, pos: Vector2, radius: int, color: Color) -> void:
	var cx := int(round(pos.x))
	var cy := int(round(pos.y))
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				if Vector2(x - pos.x, y - pos.y).length() <= radius + 0.4:
					img.set_pixel(x, y, color)

## Simple Bresenham-ish stepped line, thick enough (2 px via a small
## dab per step) to read clearly even at CANVAS_SIZE's low resolution.
func _line(img: Image, from: Vector2, to: Vector2, color: Color) -> void:
	var dist := from.distance_to(to)
	var steps := maxi(1, int(dist))
	for i in range(steps + 1):
		var p := from.lerp(to, float(i) / float(steps))
		_dab(img, p, 0, color)
