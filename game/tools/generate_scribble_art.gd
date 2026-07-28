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
## seed a genuinely randomized creature doodle: a body (one of a few
## generic shape families -- round/elongated/blocky/lumpy, picked by
## chance, not by species), plus a random assortment of horns/tail/
## wings/spikes and a variable number of eyes, none of it tied to any
## particular monster's actual design. Re-running this script
## reproduces byte-identical output per species (seeded by a hash of
## species_id), so the doodle for a given monster doesn't change
## between runs.
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

## The actual doodle: a jittery closed blob body (radius-per-angle noise,
## no relation whatsoever to the source image's real silhouette) drawn as
## one of a few generic body-shape families picked purely by chance, with
## a random assortment of horns/tail/wings/spikes bolted on and a
## variable eye count -- reads as "some kind of creature" rather than a
## blank blob, without approximating any specific monster's actual
## design. Drawn at CANVAS_SIZE then upscaled with nearest-neighbor
## filtering to FINAL_SIZE for the chunky, blocky mouse-drawn look.
func _draw_scribble(avg_color: Color, aspect: float, rng: RandomNumberGenerator) -> Image:
	var small := Image.create(CANVAS_SIZE, CANVAS_SIZE, false, Image.FORMAT_RGBA8)
	small.fill(Color(1, 1, 1, 1))

	var center := Vector2(CANVAS_SIZE / 2.0, CANVAS_SIZE / 2.0 + rng.randf_range(-2, 2))
	var base_radius_x := clampf(CANVAS_SIZE * 0.32 * clampf(aspect, 0.5, 1.8), 6.0, 17.0)
	var base_radius_y := clampf(CANVAS_SIZE * 0.32 / clampf(aspect, 0.5, 1.8), 6.0, 17.0)

	# Body shape family -- purely a chance roll, never tied to the
	# species itself, just enough variety that not every monster reads
	# as the same round blob.
	var body_roll := rng.randf()
	var angle_steps: int
	var jitter_range: float
	var lump_freq := 0.0
	var lump_amount := 0.0
	if body_roll < 0.25:
		# Round: smooth-ish wobble.
		angle_steps = 18
		jitter_range = 0.22
	elif body_roll < 0.5:
		# Elongated: stretch one random axis harder.
		angle_steps = 18
		jitter_range = 0.22
		if rng.randf() < 0.5:
			base_radius_x *= rng.randf_range(1.3, 1.7)
		else:
			base_radius_y *= rng.randf_range(1.3, 1.7)
	elif body_roll < 0.75:
		# Blocky: few control points, big jumps -- reads as jagged and
		# angular instead of smooth.
		angle_steps = 8
		jitter_range = 0.32
	else:
		# Lumpy: smooth base wobble PLUS a slower secondary sine wave,
		# so a few wide rounded bumps appear around the body.
		angle_steps = 18
		jitter_range = 0.16
		lump_freq = float(rng.randi_range(2, 4))
		lump_amount = rng.randf_range(0.18, 0.3)

	var radii: Array[float] = []
	for i in range(angle_steps):
		var lump: float = lump_amount * sin(float(i) / angle_steps * TAU * lump_freq + rng.randf() * TAU) if lump_amount > 0.0 else 0.0
		radii.append(1.0 + rng.randf_range(-jitter_range, jitter_range) + lump)

	# A scribbled fill color -- nudged well away from the sampled average
	# (not used verbatim) for some real punch, plus an unrelated
	# secondary accent color (randomly hue-shifted) for horns/wings/
	# spikes so they read as a distinct feature rather than blending
	# into the body.
	var fill_color := Color(
		clampf(avg_color.r + rng.randf_range(-0.3, 0.3), 0.05, 0.95),
		clampf(avg_color.g + rng.randf_range(-0.3, 0.3), 0.05, 0.95),
		clampf(avg_color.b + rng.randf_range(-0.3, 0.3), 0.05, 0.95),
		1.0
	)
	var outline_color := fill_color.darkened(0.55)
	var accent_color := Color.from_hsv(fposmod(fill_color.h + rng.randf_range(0.25, 0.75), 1.0), clampf(fill_color.s + 0.2, 0.3, 1.0), clampf(fill_color.v + 0.1, 0.3, 1.0))

	_fill_blob(small, center, base_radius_x, base_radius_y, angle_steps, radii, fill_color, outline_color)

	# Optional extra limbs/features -- each an independent chance roll,
	# drawn with the accent color so they pop against the body.
	if rng.randf() < 0.55:
		_draw_tail(small, center, base_radius_x, base_radius_y, accent_color, rng)
	if rng.randf() < 0.4:
		_draw_wings(small, center, base_radius_x, base_radius_y, accent_color, rng)
	var horn_count := rng.randi_range(0, 2) if rng.randf() < 0.5 else 0
	for i in range(horn_count):
		_draw_horn(small, center, base_radius_x, base_radius_y, accent_color, rng)
	if rng.randf() < 0.35:
		var spike_count := rng.randi_range(2, 5)
		for i in range(spike_count):
			_draw_spike(small, center, base_radius_x, base_radius_y, accent_color, rng)

	# One to three eyes (weighted toward the usual two), jittered
	# off-center and mismatched in size on purpose.
	var eye_roll := rng.randf()
	var eye_count := 1 if eye_roll < 0.15 else (3 if eye_roll > 0.9 else 2)
	_draw_eyes(small, center, base_radius_x, base_radius_y, eye_count, rng)

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

## Rasterizes the body: for every pixel, find its angle from center and
## the allowed radius at that angle (interpolated between the two
## nearest jittered control points), fill if inside.
func _fill_blob(img: Image, center: Vector2, radius_x: float, radius_y: float, angle_steps: int, radii: Array[float], fill_color: Color, outline_color: Color) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var dx: float = (x - center.x) / radius_x
			var dy: float = (y - center.y) / radius_y
			var dist := Vector2(dx, dy).length()
			var angle := fposmod(atan2(dy, dx), TAU)
			var slot := angle / TAU * angle_steps
			var i0 := int(floor(slot)) % angle_steps
			var i1 := (i0 + 1) % angle_steps
			var t: float = slot - floor(slot)
			var allowed: float = lerp(radii[i0], radii[i1], t)
			if dist <= allowed:
				if dist >= allowed - 0.12:
					img.set_pixel(x, y, outline_color)
				else:
					img.set_pixel(x, y, fill_color)

func _draw_eyes(img: Image, center: Vector2, radius_x: float, radius_y: float, count: int, rng: RandomNumberGenerator) -> void:
	if count == 1:
		_dab(img, center + Vector2(rng.randf_range(-2, 2), -radius_y * 0.15), 1 + rng.randi_range(0, 1), Color.BLACK)
		return
	var spread := 0.35
	for i in range(count):
		var side := -1.0 if i == 0 else (1.0 if i == 1 else 0.0)
		var pos := center + Vector2(side * radius_x * spread, -radius_y * (0.15 if i < 2 else 0.35)) + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		_dab(img, pos, 1 + rng.randi_range(0, 1), Color.BLACK)

## A wavy, tapering tail poking out from a random point on the body's
## own edge -- length/direction/wave both random.
func _draw_tail(img: Image, center: Vector2, radius_x: float, radius_y: float, color: Color, rng: RandomNumberGenerator) -> void:
	var start_angle := rng.randf_range(PI * 0.25, PI * 0.75)  # roughly the lower half
	var start := center + Vector2(cos(start_angle) * radius_x, sin(start_angle) * radius_y)
	var dir := (start - center).normalized()
	var length := (radius_x + radius_y) * rng.randf_range(0.5, 0.9)
	var segments := 3
	var prev := start
	for i in range(1, segments + 1):
		var t := float(i) / segments
		var wobble := Vector2(-dir.y, dir.x) * sin(t * PI * rng.randf_range(1.0, 2.0)) * length * 0.25
		var next: Vector2 = start + dir * length * t + wobble
		_line(img, prev, next, color)
		prev = next

## Two simple triangular "wings" jutting from either side, upper half of
## the body.
func _draw_wings(img: Image, center: Vector2, radius_x: float, radius_y: float, color: Color, rng: RandomNumberGenerator) -> void:
	for side in [-1.0, 1.0]:
		var root := center + Vector2(side * radius_x * 0.7, -radius_y * rng.randf_range(0.0, 0.2))
		var tip := root + Vector2(side * radius_x * rng.randf_range(0.7, 1.1), -radius_y * rng.randf_range(0.5, 0.9))
		var lower := root + Vector2(side * radius_x * rng.randf_range(0.4, 0.7), radius_y * rng.randf_range(0.1, 0.3))
		_line(img, root, tip, color)
		_line(img, tip, lower, color)
		_line(img, lower, root, color)

## A short spike/horn from the top of the body.
func _draw_horn(img: Image, center: Vector2, radius_x: float, radius_y: float, color: Color, rng: RandomNumberGenerator) -> void:
	var angle := rng.randf_range(PI * 1.1, PI * 1.9)  # roughly the upper half
	var root := center + Vector2(cos(angle) * radius_x * rng.randf_range(0.3, 0.7), sin(angle) * radius_y * rng.randf_range(0.6, 1.0))
	var tip := root + Vector2(cos(angle), sin(angle)) * (radius_x + radius_y) * 0.5 * rng.randf_range(0.4, 0.8)
	_line(img, root, tip, color)

## A short spike jutting out from anywhere on the body's own edge.
func _draw_spike(img: Image, center: Vector2, radius_x: float, radius_y: float, color: Color, rng: RandomNumberGenerator) -> void:
	var angle := rng.randf_range(0, TAU)
	var root := center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
	var tip := root + Vector2(cos(angle), sin(angle)) * (radius_x + radius_y) * 0.25 * rng.randf_range(0.5, 1.0)
	_line(img, root, tip, color)

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
