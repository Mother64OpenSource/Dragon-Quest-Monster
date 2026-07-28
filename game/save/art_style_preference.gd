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
## Real artwork goes through the normal load() -- it's imported by the
## editor like any other project asset. The scribble PNGs are NOT --
## they're written straight to disk at build-tool time
## (tools/generate_scribble_art.gd), completely outside the editor's
## import pipeline, so they have no .import file and load()/
## ResourceLoader.exists() can't reliably find them via a res:// path.
## Loaded the same way BackgroundDisplay already handles user-uploaded
## background images for the exact same reason (see its own doc
## comment): Image.load() on the real filesystem path, wrapped in an
## ImageTexture.
func load_texture(species: MonsterSpecies) -> Texture2D:
	if species == null or species.sprite_path.is_empty():
		return null
	if use_scribble_art:
		var scribble_res_path := "%s/%s.png" % [SCRIBBLE_DIR, species.id]
		var scribble_abs_path := ProjectSettings.globalize_path(scribble_res_path)
		if FileAccess.file_exists(scribble_abs_path):
			var image := Image.new()
			if image.load(scribble_abs_path) == OK:
				return ImageTexture.create_from_image(image)
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
