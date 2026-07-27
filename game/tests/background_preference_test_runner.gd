class_name BackgroundPreferenceTestRunner
extends RefCounted

## Local background-preference persistence checks. Uses an isolated
## user://test_background_preference.json (never the real
## user://background_preference.json) and a throwaway "external" source
## file under user:// too -- copy_absolute() doesn't care whether its
## source is truly external, only that the path is readable, so this is a
## faithful stand-in for a file picked via a real native file dialog.

const TEST_PREF_PATH := "user://test_background_preference.json"
const TEST_BACKGROUNDS_DIR := "user://test_backgrounds"
const TEST_SOURCE_PNG := "user://test_source_bg.png"
const TEST_SOURCE_GIF := "user://test_source_bg.gif"

var _all_passed := true

func run() -> bool:
	_all_passed = true
	_clear_test_state()
	_write_dummy_file(TEST_SOURCE_PNG, "not a real png, just needs bytes")
	_write_dummy_file(TEST_SOURCE_GIF, "not a real gif, just needs bytes")

	_check_default_state()
	_check_set_and_switch()
	_check_missing_source()
	_check_clear()

	_clear_test_state()

	if _all_passed:
		print("BackgroundPreferenceTestRunner: ALL CHECKS PASSED")
	else:
		print("BackgroundPreferenceTestRunner: SOME CHECKS FAILED")
	return _all_passed

func _check_default_state() -> void:
	var manager := _new_manager()
	_check("no preference exists before anything is set", not manager.has_preference())
	var pref := manager.get_preference()
	_check("get_preference() defaults to an empty background_path, never null", pref != null and pref.background_path.is_empty())

func _check_set_and_switch() -> void:
	var manager := _new_manager()
	var result_path := manager.set_background_from_external_file(TEST_SOURCE_PNG)
	_check("setting a background from a real source file returns a non-empty local path", not result_path.is_empty())
	_check("has_preference() is true once a background has been set", manager.has_preference())
	_check("the copied file actually exists on disk", FileAccess.file_exists(result_path))
	_check("get_preference() reflects the newly set path", manager.get_preference().background_path == result_path)

	# Switching from a .png to a .gif should remove the old copy, not just
	# leave it sitting there unreferenced.
	var gif_path := manager.set_background_from_external_file(TEST_SOURCE_GIF)
	_check("switching to a .gif returns a new path with the right extension", gif_path.get_extension() == "gif")
	_check("the old .png copy was removed when switching", not FileAccess.file_exists(result_path))
	_check("the new .gif copy exists", FileAccess.file_exists(gif_path))

func _check_missing_source() -> void:
	var manager := _new_manager()
	var result := manager.set_background_from_external_file("user://this_file_does_not_exist.png")
	_check("a missing source file returns an empty path without crashing", result.is_empty())

func _check_clear() -> void:
	var manager := _new_manager()
	var path := manager.set_background_from_external_file(TEST_SOURCE_PNG)
	manager.clear_background()
	_check("clear_background() resets get_preference() to an empty path", manager.get_preference().background_path.is_empty())
	_check("clear_background() removes the copied file", not FileAccess.file_exists(path))

func _new_manager() -> BackgroundPreferenceManager:
	return BackgroundPreferenceManager.new(TEST_PREF_PATH, TEST_BACKGROUNDS_DIR)

func _write_dummy_file(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()

func _clear_test_state() -> void:
	if FileAccess.file_exists(TEST_PREF_PATH):
		DirAccess.remove_absolute(TEST_PREF_PATH)
	if FileAccess.file_exists(TEST_SOURCE_PNG):
		DirAccess.remove_absolute(TEST_SOURCE_PNG)
	if FileAccess.file_exists(TEST_SOURCE_GIF):
		DirAccess.remove_absolute(TEST_SOURCE_GIF)
	var dir := DirAccess.open(TEST_BACKGROUNDS_DIR)
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		print("FAIL: %s" % label)
		_all_passed = false
