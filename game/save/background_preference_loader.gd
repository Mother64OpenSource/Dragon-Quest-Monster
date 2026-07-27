class_name BackgroundPreferenceLoader
extends RefCounted

## Same to_dict/load_from_dict/load_from_file/save_to_file shape as
## PlayerProfileLoader.

const SCHEMA_VERSION := 1

static func load_from_dict(data: Dictionary) -> BackgroundPreference:
	var pref := BackgroundPreference.new()
	pref.background_path = data.get("background_path", "")
	return pref

static func to_dict(pref: BackgroundPreference) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"background_path": pref.background_path,
	}

static func load_from_string(json_text: String) -> BackgroundPreference:
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		push_error("Failed to parse background preference JSON")
		return null
	return load_from_dict(parsed)

static func load_from_file(path: String) -> BackgroundPreference:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	return load_from_string(text)

static func save_to_file(pref: BackgroundPreference, path: String) -> bool:
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err := DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			push_error("Failed to create directory: %s" % dir_path)
			return false

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for writing: %s" % path)
		return false
	file.store_string(JSON.stringify(to_dict(pref), "  "))
	file.close()
	return true
