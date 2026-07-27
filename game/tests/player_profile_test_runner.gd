class_name PlayerProfileTestRunner
extends RefCounted

## Local player-profile data model checks: first-launch auto-creation,
## idempotency across repeated calls, save/load round-trip, dict round-trip
## (the same shape sent over the wire during the online handshake -- see
## NetworkManager.send_local_profile()), and malformed-input handling. Uses
## user://test_profile.json (never the real user://profile.json) and wipes
## it before and after run(), same isolation convention as
## TeamRosterTestRunner's user://test_teams/.

const TEST_PROFILE_PATH := "user://test_profile.json"

var _all_passed := true

func run() -> bool:
	_all_passed = true
	_clear_test_file()

	_check_first_launch_and_idempotency()
	_check_save_and_reload()
	_check_dict_round_trip()
	_check_malformed_file()

	_clear_test_file()

	if _all_passed:
		print("PlayerProfileTestRunner: ALL CHECKS PASSED")
	else:
		print("PlayerProfileTestRunner: SOME CHECKS FAILED")
	return _all_passed

func _check_first_launch_and_idempotency() -> void:
	var manager := PlayerProfileManager.new(TEST_PROFILE_PATH)
	_check("no profile exists before first use", not manager.has_profile())

	var created := manager.get_or_create_profile()
	_check("get_or_create_profile() returns a non-empty default name", not created.player_name.is_empty())
	_check(
		"get_or_create_profile() defaults the avatar to the guaranteed 'slime' species",
		created.avatar_species_id == PlayerProfileManager.DEFAULT_AVATAR_SPECIES_ID
	)
	_check("has_profile() is true once a profile has been created", manager.has_profile())

	var fetched_again := manager.get_or_create_profile()
	_check(
		"a second get_or_create_profile() call returns the SAME persisted name, not a freshly regenerated one",
		fetched_again.player_name == created.player_name
	)

func _check_save_and_reload() -> void:
	_clear_test_file()
	var manager := PlayerProfileManager.new(TEST_PROFILE_PATH)
	manager.get_or_create_profile()

	var profile := manager.load_profile()
	profile.player_name = "Eli"
	profile.avatar_species_id = "golem"
	_check("save_profile() reports success", manager.save_profile(profile))

	var fresh_manager := PlayerProfileManager.new(TEST_PROFILE_PATH)
	var reloaded := fresh_manager.load_profile()
	_check("a fresh manager instance reloads the edited name", reloaded.player_name == "Eli")
	_check("a fresh manager instance reloads the edited avatar", reloaded.avatar_species_id == "golem")

func _check_dict_round_trip() -> void:
	var profile := PlayerProfile.new()
	profile.player_name = "Iru"
	profile.avatar_species_id = "dracky"
	var round_tripped := PlayerProfileLoader.load_from_dict(PlayerProfileLoader.to_dict(profile))
	_check("PlayerProfileLoader dict round-trip preserves player_name", round_tripped.player_name == "Iru")
	_check("PlayerProfileLoader dict round-trip preserves avatar_species_id", round_tripped.avatar_species_id == "dracky")

func _check_malformed_file() -> void:
	_clear_test_file()
	var file := FileAccess.open(TEST_PROFILE_PATH, FileAccess.WRITE)
	file.store_string("{ this is not valid json ][")
	file.close()
	var manager := PlayerProfileManager.new(TEST_PROFILE_PATH)
	_check("loading a malformed profile file returns null without crashing", manager.load_profile() == null)

func _clear_test_file() -> void:
	if FileAccess.file_exists(TEST_PROFILE_PATH):
		DirAccess.remove_absolute(TEST_PROFILE_PATH)

func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		print("FAIL: %s" % label)
		_all_passed = false
