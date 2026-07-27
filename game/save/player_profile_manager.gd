class_name PlayerProfileManager
extends RefCounted

## Exactly one PlayerProfile per install, at a single fixed path -- no
## CRUD/list, unlike TeamRosterManager, since there's nothing to key by.
## get_or_create_profile() is the one entry point every caller should use:
## it auto-generates and persists a Showdown-style default ("Trainer####")
## the first time it's ever called, so no caller needs its own "is this the
## first launch" branch.

const DEFAULT_PROFILE_PATH := "user://profile.json"
## Guaranteed to exist -- the M1 hand-tuned fixture every other test/system
## in this project already treats as the canonical baseline species.
const DEFAULT_AVATAR_SPECIES_ID := "slime"

var profile_path: String

func _init(p_profile_path: String = DEFAULT_PROFILE_PATH) -> void:
	profile_path = p_profile_path

func has_profile() -> bool:
	return FileAccess.file_exists(profile_path)

func load_profile() -> PlayerProfile:
	return PlayerProfileLoader.load_from_file(profile_path)

func save_profile(profile: PlayerProfile) -> bool:
	return PlayerProfileLoader.save_to_file(profile, profile_path)

func get_or_create_profile() -> PlayerProfile:
	if has_profile():
		return load_profile()
	var profile := PlayerProfile.new()
	profile.player_name = _generate_default_name()
	profile.avatar_species_id = DEFAULT_AVATAR_SPECIES_ID
	save_profile(profile)
	return profile

func _generate_default_name() -> String:
	return "Trainer%04d" % (randi() % 10000)
