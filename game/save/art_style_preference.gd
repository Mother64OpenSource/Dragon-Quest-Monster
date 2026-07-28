class_name ArtStylePreferenceManager
extends Node

## Global toggle between the real monster artwork and the alternate
## "scribble" placeholder art (see tools/generate_scribble_art.gd) --
## registered as an autoload (see project.godot) rather than owned per-
## screen like BackgroundPreferenceManager, since resolving a sprite path
## needs to be reachable from every screen that shows a monster icon
## (team builder, monster picker, battle arena, battle cards, profile
## avatar, network setup), not just one.

signal changed(use_scribble_art: bool)

const PREF_PATH := "user://art_style_preference.json"
const SCRIBBLE_DIR := "res://assets/monsters_scribble"

var use_scribble_art: bool = false

func _ready() -> void:
	_load()

## The one thing every call site actually needs: given a species, which
## texture should actually be shown right now. Falls back to the real
## artwork if a scribble version doesn't exist for this species (e.g. a
## species added after the last batch-generation run), or if scribble
## mode isn't on at all.
##
## Both the real artwork and the scribble PNGs go through a plain load()
## now -- the scribble PNGs were written straight to disk at build-tool
## time (tools/generate_scribble_art.gd), completely outside the editor's
## import pipeline, but a later editor filesystem rescan generated real
## .import files for all 808 of them (see wiki/log.md), so the standard
## resource loader resolves them correctly in both the editor and an
## exported build. An earlier version of this method bypassed load()
## with Image.load_png_from_buffer() on raw FileAccess bytes specifically
## because that rescan hadn't happened yet for these files -- if a
## FRESHLY generated scribble PNG ever shows up missing once exported
## despite loading fine in the editor, the fix is re-running that rescan
## so it gets a proper .import too, not reintroducing the bypass (Godot's
## own engine explicitly warns that loading an IMAGE FILE, as opposed to
## an imported Texture2D resource, straight off a res:// path "will not
## work on export").
func load_texture(species: MonsterSpecies) -> Texture2D:
	if species == null or species.sprite_path.is_empty():
		return null
	if use_scribble_art:
		var scribble_res_path := "%s/%s.png" % [SCRIBBLE_DIR, species.id]
		var scribble_texture: Texture2D = load(scribble_res_path)
		if scribble_texture != null:
			return scribble_texture
	return load(species.sprite_path)

func set_use_scribble_art(value: bool) -> void:
	if use_scribble_art == value:
		return
	use_scribble_art = value
	_save()
	changed.emit(use_scribble_art)

func _load() -> void:
	if not FileAccess.file_exists(PREF_PATH):
		return
	var file := FileAccess.open(PREF_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("use_scribble_art"):
		use_scribble_art = bool(parsed["use_scribble_art"])

func _save() -> void:
	var file := FileAccess.open(PREF_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"use_scribble_art": use_scribble_art}))
	file.close()
