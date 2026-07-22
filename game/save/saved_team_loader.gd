class_name SavedTeamLoader
extends RefCounted

## Handles both the "list of saved teams" persistence format and standalone
## import/export — they're the same JSON shape, so the same to_dict/
## load_from_dict pair serves both.

const SCHEMA_VERSION := 1

static func load_from_dict(data: Dictionary) -> SavedTeam:
	var team := SavedTeam.new()
	team.id = data.get("id", "")
	team.team_name = data.get("team_name", "")
	var members: Array[MonsterLoadout] = []
	for member_data in data.get("members", []):
		members.append(MonsterLoadoutLoader.load_from_dict(member_data))
	team.members = members
	return team

static func to_dict(team: SavedTeam) -> Dictionary:
	var members_data: Array = []
	for member in team.members:
		members_data.append(MonsterLoadoutLoader.to_dict(member))
	return {
		"schema_version": SCHEMA_VERSION,
		"id": team.id,
		"team_name": team.team_name,
		"members": members_data,
	}

static func load_from_string(json_text: String) -> SavedTeam:
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		push_error("Failed to parse team JSON")
		return null
	return load_from_dict(parsed)

static func load_from_file(path: String) -> SavedTeam:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	return load_from_string(text)

static func save_to_file(team: SavedTeam, path: String) -> bool:
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
	file.store_string(JSON.stringify(to_dict(team), "  "))
	file.close()
	return true
