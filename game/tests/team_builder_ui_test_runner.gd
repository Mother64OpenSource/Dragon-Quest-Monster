class_name TeamBuilderUiTestRunner
extends RefCounted

## Runs the Milestone 3 UI checks by instancing the real scene tree and
## calling handler methods directly (no simulated mouse/keyboard input —
## real drag-and-drop specifically cannot be driven headlessly; see the M3
## plan). Uses an isolated user://test_teams_ui/ roster dir, wiped before
## and after run(), and never touches real player save data.

const TEST_TEAMS_DIR := "user://test_teams_ui/"
const TEST_PROFILE_PATH := "user://test_profile_ui.json"
const TEST_BACKGROUND_PREF_PATH := "user://test_background_pref_ui.json"
const TEST_BACKGROUND_DIR := "user://test_backgrounds_ui"
const ScreenScene := preload("res://ui/team_builder/team_builder_screen.tscn")
const RowScene := preload("res://ui/team_builder/team_member_row.tscn")

var _all_passed := true
var _tree: SceneTree
var _screen: TeamBuilderScreen

func run(tree: SceneTree) -> bool:  # coroutine (awaits a frame internally)
	_all_passed = true
	_tree = tree
	_clear_test_dir()
	_clear_test_profile()
	_clear_test_backgrounds()

	_screen = ScreenScene.instantiate()
	_screen.teams_dir_override = TEST_TEAMS_DIR
	_screen.profile_path_override = TEST_PROFILE_PATH
	_screen.background_pref_path_override = TEST_BACKGROUND_PREF_PATH
	_screen.background_dir_override = TEST_BACKGROUND_DIR
	_tree.root.add_child(_screen)
	# _ready()/@onready resolution for freshly add_child()-ed nodes isn't
	# dispatched until the engine processes a frame — not synchronous within
	# add_child() itself when called from a SceneTree's _initialize().
	await _tree.process_frame

	_check_wiring()
	_check_crud_and_selection()
	_check_load_team_and_add_species()
	_check_row_edits()
	_check_weapon_button()
	_check_reorder()
	await _check_degradation()
	_check_validation_banner()
	_check_resistances_shown()
	await _check_skill_point_allocation()
	_check_formation_grid()
	_check_profile_indicator()
	_check_background_wiring()

	_screen.queue_free()
	_clear_test_dir()
	_clear_test_profile()
	_clear_test_backgrounds()

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
	# An empty Main Party row still shows one EmptyTeamSlot spanning the
	# full 4 slot-point budget, so "0 members" is checked by counting
	# TeamMemberRow children specifically, not the row's raw child count.
	_check("new team starts with 0 member rows", _count_member_rows(editor._main_party_row) == 0)
	_check("empty Main Party shows one empty slot spanning all 4 slot-points", editor._main_party_row.get_child_count() == 1)

	editor._on_species_chosen("slime")
	var slime_species := _screen.monster_db.get_species("slime")
	_check("member row added to the Main Party", _count_member_rows(editor._main_party_row) == 1)
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

	var row: TeamMemberRow = editor._main_party_row.get_child(0)
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

## slime can equip sword/spear/axe/club/whip but NOT claw/staff (real
## Weapons-grid data, see wiki/log.md) -- exercises that the row's dropdown
## is actually filtered per-species, not just "every weapon."
func _check_weapon_button() -> void:
	var editor := _screen._team_editor_panel
	var team_id := _screen.roster.create_team("Weapon Button Test").id
	editor.load_team(team_id)
	editor._on_species_chosen("slime")

	var row: TeamMemberRow = editor._main_party_row.get_child(0)
	_check("weapon button defaults to (No Weapon) selected", row._weapon_button.selected == 0)
	_check("weapon button offers compatible copper_sword", row._weapon_button_ids.has("copper_sword"))
	_check("weapon button excludes incompatible stone_claws (slime can't equip claws)", not row._weapon_button_ids.has("stone_claws"))
	_check("weapon button excludes incompatible cypress_stick (slime can't equip staves)", not row._weapon_button_ids.has("cypress_stick"))

	var sword_index := row._weapon_button_ids.find("copper_sword")
	row._on_weapon_selected(sword_index)
	_check("selecting a weapon updates the loadout", editor.current_team.members[0].equipped_weapon_id == "copper_sword")

	var reloaded := _screen.roster.get_team(team_id)
	_check("equipped weapon persists to disk", reloaded.members[0].equipped_weapon_id == "copper_sword")

	row._on_weapon_selected(0)
	_check("selecting (No Weapon) clears the loadout's equipped_weapon_id", editor.current_team.members[0].equipped_weapon_id == "")

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

	row1.setup(bad_species_loadout, 0, _screen.monster_db, _screen.skill_db, _screen.skillset_db, _screen.trait_db)
	_check(
		"unknown species_id renders a degraded label instead of crashing",
		row1._species_label.text.begins_with("Unknown species")
	)
	row1.queue_free()

	row2.setup(extra_skill_loadout, 0, _screen.monster_db, _screen.skill_db, _screen.skillset_db, _screen.trait_db)
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

	# Every monster can invest in every skillset -- not just the handful
	# curated into species.available_skill_sets. "guard" is deliberately NOT
	# in slime.json's curated list, so it's a real test of the restriction
	# actually being gone rather than of data that happened to include it.
	_check("every skillset is shown, not just the species' curated list", dialog._panels_list.get_child_count() == _screen.skillset_db.get_all_skillsets().size())
	loadout.skill_point_allocation["guard"] = 56
	_check(
		"a skillset outside slime's curated list is still a valid, unlocking allocation",
		TeamRosterManager.get_unlocked_skill_ids(loadout, slime_species, _screen.skillset_db).has("selflessness")
	)
	_check("that allocation passes validation (no species restriction anymore)", _screen.roster.validate_member(loadout, _screen.monster_db, _screen.skillset_db).is_empty())
	loadout.skill_point_allocation.erase("guard")

	# The search field narrows the visible panel list without touching data.
	dialog._search_edit.text = "slimer"
	dialog._on_search_text_changed("slimer")
	_check("searching filters down to matching panels only", dialog._panels_list.get_child_count() == 1)
	dialog._search_edit.text = ""
	dialog._on_search_text_changed("")

	dialog._on_points_changed(2.0, "slimer")
	_check(
		"allocating 2 points in slimer unlocks frizz (2 SP threshold)",
		TeamRosterManager.get_unlocked_skill_ids(loadout, slime_species, _screen.skillset_db).has("frizz")
	)
	_check("allocation is recorded on the loadout", int(loadout.skill_point_allocation.get("slimer", 0)) == 2)

	# Match on "— Frizz (" (display name flanked by the label's own
	# separator/MP-paren) rather than a bare "Frizz" substring -- several
	# other real skills (Frizzle, Frizz Cracker) also contain "Frizz" and
	# would otherwise be matched first, since every skillset is listed now.
	var frizz_checkbox := _find_checkbox(dialog._panels_list, "— Frizz (")
	var frizz_description: String = _screen.skill_db.get_skill("frizz").description
	_check("frizz's checkbox exists once unlocked", frizz_checkbox != null)
	_check(
		"frizz's checkbox tooltip shows its move description",
		frizz_checkbox != null and not frizz_description.is_empty() and frizz_checkbox.tooltip_text == frizz_description
	)

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

	var weapon_mismatch_team_id := _screen.roster.create_team("Weapon Mismatch Team").id
	editor.load_team(weapon_mismatch_team_id)
	editor._on_species_chosen("slime")
	editor.current_team.members[0].equipped_weapon_id = "stone_claws"
	editor._update_validation_banner()
	_check("a slime equipped with an incompatible claw shows the validation banner", editor._validation_banner.visible)

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

## Main/Second Party rows are capped by slot-POINTS (TeamFormationLayout),
## not monster count: species used here are slime/dracky/golem/healslime
## (all 1-slot), aamon (2-slot), and asura_zoma (4-slot). Real
## drag-and-drop onto an EmptyTeamSlot can't be exercised headlessly (same
## M3 limitation as row reordering), so _on_empty_slot_member_dropped() is
## called directly here, exactly like _check_reorder() already does for
## _on_row_reorder_requested() -- proving the data-mutation logic a real
## drop would trigger, not the drag gesture itself.
func _check_formation_grid() -> void:
	var editor := _screen._team_editor_panel

	# A single 4-slot monster fills the entire Main Party by itself --
	# proving slot-points, not monster count, are what's actually capped.
	var team_a := _screen.roster.create_team("Formation Big").id
	editor.load_team(team_a)
	editor._on_species_chosen("asura_zoma")
	_check(
		"a 4-slot monster alone fills the Main Party's 4 slot-points",
		_count_member_rows(editor._main_party_row) == 1 and _count_empty_slots(editor._main_party_row) == 0
	)
	editor._on_species_chosen("slime")
	_check(
		"once the 4-slot monster fills Main Party, the next member spills into Second Party",
		_count_member_rows(editor._main_party_row) == 1 and _count_member_rows(editor._second_party_row) == 1
	)
	_screen.roster.delete_team(team_a)

	# A 2-slot monster should leave exactly 2 slot-points' worth of empty
	# space, sized accordingly (not a flat 1-cell placeholder).
	var team_b := _screen.roster.create_team("Formation TwoSlot").id
	editor.load_team(team_b)
	editor._on_species_chosen("aamon")
	var main_empty: EmptyTeamSlot = editor._main_party_row.get_child(1)
	_check(
		"a 2-slot monster leaves an empty slot sized to the remaining 2 slot-points",
		main_empty is EmptyTeamSlot and is_equal_approx(main_empty.custom_minimum_size.x, TeamMemberRow.SPACE_UNIT_WIDTH * 2.0)
	)
	_screen.roster.delete_team(team_b)

	# Four 1-slot monsters exactly fill Main Party (4 slot-points); a 5th
	# spills into Second Party rather than being rejected.
	var team_c := _screen.roster.create_team("Formation FourOnes").id
	editor.load_team(team_c)
	for i in range(4):
		editor._on_species_chosen("slime")
	_check(
		"four 1-slot monsters exactly fill the Main Party with no empty slot left",
		_count_member_rows(editor._main_party_row) == 4 and _count_empty_slots(editor._main_party_row) == 0
	)
	editor._on_species_chosen("dracky")
	_check(
		"a 5th 1-slot monster spills into the Second Party",
		_count_member_rows(editor._second_party_row) == 1
	)

	# Fill Second Party's remaining 3 slot-points exactly (3 more 1-slot
	# monsters), then confirm the team is genuinely full: a monster that
	# doesn't fit either party's remaining budget is rejected outright.
	editor._on_species_chosen("golem")
	editor._on_species_chosen("healslime")
	editor._on_species_chosen("slime")
	_check(
		"Second Party is now also full (4 slot-points)",
		_count_member_rows(editor._second_party_row) == 4 and _count_empty_slots(editor._second_party_row) == 0
	)
	var member_count_before := editor.current_team.members.size()
	editor._on_species_chosen("dracky")
	_check(
		"adding beyond both parties' combined 8 slot-points is rejected, not appended",
		editor.current_team.members.size() == member_count_before
	)
	_screen.roster.delete_team(team_c)

	# A partially-filled team: dropping a member onto an empty slot sends
	# it to the end of the whole list, regardless of which party's empty
	# slot it was dropped on.
	var team_d := _screen.roster.create_team("Formation Partial").id
	editor.load_team(team_d)
	editor._on_species_chosen("slime")
	editor._on_species_chosen("dracky")
	editor._on_species_chosen("golem")
	_check(
		"3 one-slot members all fit in the Main Party with 1 slot-point left over",
		_count_member_rows(editor._main_party_row) == 3 and _count_empty_slots(editor._main_party_row) == 1
	)

	editor._on_empty_slot_member_dropped(0)
	var ids: Array[String] = []
	for member in editor.current_team.members:
		ids.append(member.species_id)
	_check("dropping the first member onto an empty slot sends it to the end", ids == ["dracky", "golem", "slime"])

	_screen.roster.delete_team(team_d)

## Never calls _on_profile_button_pressed() (which would popup_centered()
## the dialog as a real Window) -- no existing test in this suite has
## exercised a real popup headlessly, so this sticks to the established
## "call handler methods directly" convention: setup() the dialog and
## trigger its _on_confirmed() handler directly, same as every other
## dialog check in this file skips simulated mouse/keyboard input.
func _check_profile_indicator() -> void:
	_check("profile button auto-populates with a default name", not _screen._profile_button.text.is_empty())
	_check("profile button auto-populates with a default avatar icon", _screen._profile_button.icon != null)

	var on_disk := PlayerProfileManager.new(TEST_PROFILE_PATH).load_profile()
	_check(
		"the auto-created profile is persisted to the isolated test path",
		on_disk != null and on_disk.player_name == _screen._profile_button.text
	)

	var dialog := _screen._profile_dialog
	dialog.setup(_screen._profile, _screen.monster_db, _screen.trait_db)
	dialog._name_edit.text = "Eli"
	dialog._on_avatar_chosen("golem")
	dialog._on_confirmed()

	_check("editing the profile updates the button's displayed name", _screen._profile_button.text == "Eli")
	var golem_icon_path: String = _screen.monster_db.get_species("golem").sprite_path
	_check(
		"editing the profile updates the button's displayed icon",
		_screen._profile_button.icon != null and _screen._profile_button.icon.resource_path == golem_icon_path
	)

	var reloaded := PlayerProfileManager.new(TEST_PROFILE_PATH).load_profile()
	_check("editing the profile persists the new name to disk", reloaded != null and reloaded.player_name == "Eli")
	_check("editing the profile persists the new avatar to disk", reloaded != null and reloaded.avatar_species_id == "golem")

## Never calls _on_change_background_pressed() (which would popup_centered()
## the FileDialog as a real Window) -- same "call handler methods directly"
## convention _check_profile_indicator() already follows for its own dialog.
func _check_background_wiring() -> void:
	_check("background display resolved", _screen._background_display != null)
	_check(
		"no preference set yet shows the fallback gradient",
		_screen._background_display._texture_rect.texture is GradientTexture2D
	)

	var source_path := "user://test_background_source_ui.png"
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 1, 0, 1))
	image.save_png(source_path)

	_screen._on_background_file_selected(source_path)
	_check(
		"choosing a background swaps the display to the loaded image",
		_screen._background_display._texture_rect.texture is ImageTexture
	)

	var pref := _screen.background_pref_manager.get_preference()
	_check("choosing a background persists a non-empty preference path", not pref.background_path.is_empty())
	_check(
		"the persisted path lives under the isolated test backgrounds dir, not the real one",
		pref.background_path.begins_with(TEST_BACKGROUND_DIR)
	)

	if FileAccess.file_exists(source_path):
		DirAccess.remove_absolute(source_path)

func _count_member_rows(container: Container) -> int:
	var count := 0
	for child in container.get_children():
		if child is TeamMemberRow:
			count += 1
	return count

func _count_empty_slots(container: Container) -> int:
	var count := 0
	for child in container.get_children():
		if child is EmptyTeamSlot:
			count += 1
	return count

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

func _clear_test_profile() -> void:
	if FileAccess.file_exists(TEST_PROFILE_PATH):
		DirAccess.remove_absolute(TEST_PROFILE_PATH)

func _clear_test_backgrounds() -> void:
	if FileAccess.file_exists(TEST_BACKGROUND_PREF_PATH):
		DirAccess.remove_absolute(TEST_BACKGROUND_PREF_PATH)
	var dir := DirAccess.open(TEST_BACKGROUND_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func _find_checkbox(root: Node, text_contains: String) -> CheckBox:
	for child in root.get_children():
		if child is CheckBox and (child as CheckBox).text.contains(text_contains):
			return child
		var found := _find_checkbox(child, text_contains)
		if found != null:
			return found
	return null

func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		print("FAIL: %s" % label)
		_all_passed = false
