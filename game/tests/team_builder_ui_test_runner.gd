class_name TeamBuilderUiTestRunner
extends RefCounted

## Runs the Milestone 3 UI checks by instancing the real scene tree and
## calling handler methods directly (no simulated mouse/keyboard input —
## real drag-and-drop specifically cannot be driven headlessly; see the M3
## plan). Uses an isolated user://test_teams_ui/ roster dir, wiped before
## and after run(), and never touches real player save data.

const TEST_TEAMS_DIR := "user://test_teams_ui/"
const ScreenScene := preload("res://ui/team_builder/team_builder_screen.tscn")
const RowScene := preload("res://ui/team_builder/team_member_row.tscn")

var _all_passed := true
var _tree: SceneTree
var _screen: TeamBuilderScreen

func run(tree: SceneTree) -> bool:  # coroutine (awaits a frame internally)
	_all_passed = true
	_tree = tree
	_clear_test_dir()

	_screen = ScreenScene.instantiate()
	_screen.teams_dir_override = TEST_TEAMS_DIR
	_tree.root.add_child(_screen)
	# _ready()/@onready resolution for freshly add_child()-ed nodes isn't
	# dispatched until the engine processes a frame — not synchronous within
	# add_child() itself when called from a SceneTree's _initialize().
	await _tree.process_frame

	_check_wiring()
	_check_crud_and_selection()
	_check_load_team_and_add_species()
	_check_row_edits()
	_check_reorder()
	await _check_degradation()
	_check_validation_banner()
	_check_resistances_shown()
	await _check_skill_point_allocation()

	_screen.queue_free()
	_clear_test_dir()

	if _all_passed:
		print("TeamBuilderUiTestRunner: ALL CHECKS PASSED")
	else:
		print("TeamBuilderUiTestRunner: SOME CHECKS FAILED")
	return _all_passed

func _check_wiring() -> void:
	_check("team_list_panel resolved", _screen._team_list_panel != null)
	_check("team_editor_panel resolved", _screen._team_editor_panel != null)
	_check("at least 4 species loaded", _screen.monster_db.get_all_species().size() >= 4)
	# Real fixture data adds many more skills from imported movesets, so check
	# a floor rather than the exact Milestone 1 count.
	_check("skill_db loaded at least 7 skills", _screen.skill_db.get_all_skills().size() >= 7)

func _check_crud_and_selection() -> void:
	var list_panel := _screen._team_list_panel
	var selected_ids: Array[String] = []
	var probe := func(id: String) -> void: selected_ids.append(id)
	list_panel.team_selected.connect(probe)

	list_panel._on_new_pressed()
	_check("New creates a team and selects it", selected_ids.size() == 1 and not selected_ids[0].is_empty())
	var first_id: String = selected_ids[0] if selected_ids.size() > 0 else ""
	_check("new team appears in TeamsList", list_panel._teams_list.item_count == 1)

	list_panel._on_duplicate_pressed()
	_check(
		"Duplicate creates a second, distinct team",
		selected_ids.size() == 2 and selected_ids[1] != first_id
	)
	_check("2 teams now listed", list_panel._teams_list.item_count == 2)

	list_panel._on_delete_confirmed()
	_check("Delete removes the team", list_panel._teams_list.item_count == 1)
	_check("team_selected('') emitted after delete", selected_ids[selected_ids.size() - 1] == "")

	list_panel.team_selected.disconnect(probe)
	if not first_id.is_empty():
		_screen.roster.delete_team(first_id)
	list_panel.refresh_list()

func _check_load_team_and_add_species() -> void:
	var editor := _screen._team_editor_panel
	var team_id := _screen.roster.create_team("Load Test").id

	editor.load_team(team_id)
	_check("load_team populates name field", editor._team_name_edit.text == "Load Test")
	_check("new team starts with 0 member rows", editor._members_list.get_child_count() == 0)

	editor._on_species_chosen("slime")
	var slime_species := _screen.monster_db.get_species("slime")
	_check("member row added", editor._members_list.get_child_count() == 1)
	_check(
		"new member defaults to all of the species' starting skills",
		# NOTE: editor.current_team is the authoritative in-memory object the
		# UI actually mutates — TeamRosterManager.get_team()/create_team()
		# return fresh Resource instances read from disk, so a separately
		# held reference would never see edits made through the editor panel.
		editor.current_team.members[0].equipped_skill_ids == slime_species.starting_skill_ids
	)

	var reloaded := _screen.roster.get_team(team_id)
	_check(
		"added member persists to disk",
		reloaded.members.size() == 1 and reloaded.members[0].species_id == "slime"
	)

	_screen.roster.delete_team(team_id)

func _check_row_edits() -> void:
	var editor := _screen._team_editor_panel
	var team_id := _screen.roster.create_team("Row Edit Test").id
	editor.load_team(team_id)
	editor._on_species_chosen("dracky")

	var row: TeamMemberRow = editor._members_list.get_child(0)
	row._apply_nickname("Nicky")
	_check("nickname edit updates the loadout", editor.current_team.members[0].nickname == "Nicky")

	var reloaded := _screen.roster.get_team(team_id)
	_check("nickname edit persists to disk", reloaded.members[0].nickname == "Nicky")

	# "zam" unlocks at 3 SP in dracky's "dark_knight" panel.
	row._skill_point_dialog.show_for(editor.current_team.members[0], row._species, _screen.skill_db, _screen.skillset_db)
	row._skill_point_dialog._on_points_changed(3.0, "dark_knight")
	row._skill_point_dialog._on_skill_toggled(true, "zam")
	_check("toggling a skill on via the row's dialog equips it", editor.current_team.members[0].equipped_skill_ids.has("zam"))

	row._skill_point_dialog._on_skill_toggled(false, "zam")
	_check(
		"toggling a skill off via the row's dialog removes it from equipped_skill_ids",
		not editor.current_team.members[0].equipped_skill_ids.has("zam")
	)

	_screen.roster.delete_team(team_id)

func _check_reorder() -> void:
	var editor := _screen._team_editor_panel
	var team_id := _screen.roster.create_team("Reorder Test").id
	editor.load_team(team_id)
	editor._on_species_chosen("slime")
	editor._on_species_chosen("dracky")
	editor._on_species_chosen("golem")
	_check("3 members added for reorder check", editor.current_team.members.size() == 3)

	editor._on_row_reorder_requested(0, 2)
	var ids: Array[String] = []
	for member in editor.current_team.members:
		ids.append(member.species_id)
	_check("reorder(0,2) moves slime to the end: [dracky,golem,slime]", ids == ["dracky", "golem", "slime"])

	_screen.roster.delete_team(team_id)

func _check_degradation() -> void:
	var bad_species_loadout := MonsterLoadout.new()
	bad_species_loadout.species_id = "nonexistent_species"
	var row1: TeamMemberRow = RowScene.instantiate()
	_tree.root.add_child(row1)

	# "double_slash" isn't reachable from any of slime's available panels --
	# exercises the row/dialog not crashing on an out-of-sync equipped skill
	# (e.g. left over from an import or a since-changed allocation).
	var extra_skill_loadout := MonsterLoadout.new()
	extra_skill_loadout.species_id = "slime"
	extra_skill_loadout.equipped_skill_ids = ["attack", "double_slash"]
	var row2: TeamMemberRow = RowScene.instantiate()
	_tree.root.add_child(row2)

	# Both rows' own @onready children need one frame to resolve, same as
	# the screen itself did in run().
	await _tree.process_frame

	row1.setup(bad_species_loadout, 0, _screen.monster_db, _screen.skill_db, _screen.skillset_db)
	_check(
		"unknown species_id renders a degraded label instead of crashing",
		row1._species_label.text.begins_with("Unknown species")
	)
	row1.queue_free()

	row2.setup(extra_skill_loadout, 0, _screen.monster_db, _screen.skill_db, _screen.skillset_db)
	_check("known species with an out-of-panel skill doesn't crash the row", row2._skills_button.visible)
	_check("skills button shows the raw equipped count", row2._skills_button.text == "Skills (2)")

	var slime_species := _screen.monster_db.get_species("slime")
	row2._skill_point_dialog.show_for(extra_skill_loadout, slime_species, _screen.skill_db, _screen.skillset_db)
	_check(
		"opening the dialog prunes an equipped skill no panel allocation unlocks",
		not extra_skill_loadout.equipped_skill_ids.has("double_slash")
	)
	row2.queue_free()

func _check_skill_point_allocation() -> void:
	var loadout := MonsterLoadout.new()
	loadout.species_id = "slime"
	var slime_species := _screen.monster_db.get_species("slime")
	_check("slime has more than one available skill panel", slime_species.available_skill_sets.size() > 1)

	# Build a standalone dialog instance rather than digging one out of a row,
	# to keep this check independent of row/dialog wiring internals.
	var dialog_scene := preload("res://ui/team_builder/skill_point_dialog.tscn")
	var dialog: SkillPointDialog = dialog_scene.instantiate()
	_tree.root.add_child(dialog)
	await _tree.process_frame

	dialog.show_for(loadout, slime_species, _screen.skill_db, _screen.skillset_db)
	_check("frizz starts locked with 0 points allocated", not TeamRosterManager.get_unlocked_skill_ids(loadout, slime_species, _screen.skillset_db).has("frizz"))

	dialog._on_points_changed(2.0, "slimer")
	_check(
		"allocating 2 points in slimer unlocks frizz (2 SP threshold)",
		TeamRosterManager.get_unlocked_skill_ids(loadout, slime_species, _screen.skillset_db).has("frizz")
	)
	_check("allocation is recorded on the loadout", int(loadout.skill_point_allocation.get("slimer", 0)) == 2)

	dialog._on_skill_toggled(true, "frizz")
	_check("toggling an unlocked skill's checkbox equips it", loadout.equipped_skill_ids.has("frizz"))

	dialog._on_points_changed(0.0, "slimer")
	_check(
		"reallocating away from a threshold re-locks and unequips its skill",
		not loadout.equipped_skill_ids.has("frizz")
	)

	dialog.queue_free()

func _check_validation_banner() -> void:
	var editor := _screen._team_editor_panel

	var valid_team_id := _screen.roster.create_team("Valid Team").id
	editor.load_team(valid_team_id)
	editor._on_species_chosen("slime")
	_check("valid team hides the validation banner", not editor._validation_banner.visible)

	var invalid_team_id := _screen.roster.create_team("Invalid Team").id
	editor.load_team(invalid_team_id)
	var bad_loadout := MonsterLoadout.new()
	bad_loadout.species_id = "nonexistent_species"
	# Mutate editor.current_team directly (not a separately held reference) —
	# see the note in _check_load_team_and_add_species.
	_screen.roster.add_member(editor.current_team, bad_loadout)
	editor._rebuild_rows()
	editor._update_validation_banner()
	_check("invalid team shows the validation banner", editor._validation_banner.visible)

	_screen.roster.delete_team(valid_team_id)
	_screen.roster.delete_team(invalid_team_id)

func _check_resistances_shown() -> void:
	var editor := _screen._team_editor_panel
	var picker := editor._monster_picker
	var slime_species := _screen.monster_db.get_species("slime")
	_check("slime fixture has resistance data to display", not slime_species.resistances.is_empty())

	picker._show_details(slime_species)
	_check("details label shows a Resistances section", picker._details_label.text.contains("Resistances"))
	for code in slime_species.resistances:
		_check(
			"details label shows resistance code %s" % code,
			picker._details_label.text.contains(code)
		)

	picker._show_details(null)
	_check("clearing details hides resistance text", not picker._details_label.text.contains("Resistances:"))

func _clear_test_dir() -> void:
	var dir := DirAccess.open(TEST_TEAMS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		print("FAIL: %s" % label)
		_all_passed = false
