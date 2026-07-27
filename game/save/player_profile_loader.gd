class_name PlayerProfileLoader
extends RefCounted

## Same to_dict/load_from_dict/load_from_file/save_to_file shape as
## SavedTeamLoader -- this dict is also what gets sent over the wire during
## the online handshake (see NetworkManager.send_local_profile()), not just
## the on-disk format.

const SCHEMA_VERSION := 1

static func load_from_dict(data: Dictionary) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.player_name = data.get("player_name", "")
	profile.avatar_species_id = data.get("avatar_species_id", "")
	return profile

static func to_dict(profile: PlayerProfile) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"player_name": profile.player_name,
		"avatar_species_id": profile.avatar_species_id,
	}

static func load_from_string(json_text: String) -> PlayerProfile:
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		push_error("Failed to parse player profile JSON")
		return null
	return load_from_dict(parsed)

static func load_from_file(path: String) -> PlayerProfile:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	return load_from_string(text)

static func save_to_file(profile: PlayerProfile, path: String) -> bool:
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
	file.store_string(JSON.stringify(to_dict(profile), "  "))
	file.close()
	return true
