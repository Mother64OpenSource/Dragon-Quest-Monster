class_name BackgroundPreferenceManager
extends RefCounted

## Exactly one chosen background per install, same "single fixed path, no
## CRUD" shape as PlayerProfileManager. The chosen file is always COPIED
## into user://backgrounds/ under a fixed name (not referenced at its
## original external location) -- the source could be anywhere on the
## player's disk, including removable media, and could move or be deleted
## after being chosen; only a local copy survives that reliably.

const DEFAULT_PREF_PATH := "user://background_preference.json"
const DEFAULT_BACKGROUNDS_DIR := "user://backgrounds"

var pref_path: String
var backgrounds_dir: String

func _init(p_pref_path: String = DEFAULT_PREF_PATH, p_backgrounds_dir: String = DEFAULT_BACKGROUNDS_DIR) -> void:
	pref_path = p_pref_path
	backgrounds_dir = p_backgrounds_dir.trim_suffix("/")

func has_preference() -> bool:
	return FileAccess.file_exists(pref_path)

## Never null -- an empty background_path means "no custom background
## chosen yet, caller should show the default," same "no separate branch
## needed at call sites" reasoning as PlayerProfileManager.get_or_create_profile().
func get_preference() -> BackgroundPreference:
	if not has_preference():
		return BackgroundPreference.new()
	var loaded := BackgroundPreferenceLoader.load_from_file(pref_path)
	return loaded if loaded != null else BackgroundPreference.new()

## Copies source_path (anywhere on disk, from a native file dialog) into
## user://backgrounds/ under a fixed name derived from its own extension
## (so a second choice overwrites the first rather than accumulating old
## copies forever), persists the preference, and returns the new local
## path -- or "" if the copy failed (source unreadable, disk full, etc.).
func set_background_from_external_file(source_path: String) -> String:
	if not FileAccess.file_exists(source_path):
		push_error("Background source file not found: %s" % source_path)
		return ""

	if not DirAccess.dir_exists_absolute(backgrounds_dir):
		var mkdir_err := DirAccess.make_dir_recursive_absolute(backgrounds_dir)
		if mkdir_err != OK:
			push_error("Failed to create directory: %s" % backgrounds_dir)
			return ""

	var extension := source_path.get_extension().to_lower()
	var dest_path := "%s/current_background.%s" % [backgrounds_dir, extension]
	_clear_existing_background_files(backgrounds_dir)
	var copy_err := DirAccess.copy_absolute(source_path, dest_path)
	if copy_err != OK:
		push_error("Failed to copy background file to %s (error %d)" % [dest_path, copy_err])
		return ""

	var pref := BackgroundPreference.new()
	pref.background_path = dest_path
	BackgroundPreferenceLoader.save_to_file(pref, pref_path)
	return dest_path

## Deletes any previously copied "current_background.*" files first --
## otherwise switching from a .gif to a .png would leave the old .gif
## sitting there unreferenced forever.
func _clear_existing_background_files(backgrounds_dir: String) -> void:
	var dir := DirAccess.open(backgrounds_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("current_background."):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func clear_background() -> void:
	var pref := BackgroundPreference.new()
	pref.background_path = ""
	BackgroundPreferenceLoader.save_to_file(pref, pref_path)
	_clear_existing_background_files(backgrounds_dir)
