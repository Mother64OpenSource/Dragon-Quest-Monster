class_name TeamEditorPanel
extends PanelContainer

## Shows the currently selected team's name + members, handles all
## member-level mutation (add/remove/reorder/edit) and persists via the
## injected TeamRosterManager. Auto-saves after every discrete edit — no
## manual Save button (see Milestone 3 plan for rationale).

signal team_updated(team: SavedTeam)

const TeamMemberRowScene := preload("res://ui/team_builder/team_member_row.tscn")

var roster: TeamRosterManager
var monster_db: MonsterDatabase
var skill_db: SkillDatabase
var skillset_db: SkillSetDatabase
var current_team: SavedTeam = null

@onready var _content: Control = $Content
@onready var _empty_label: Label = $EmptyStateLabel
@onready var _validation_banner: Label = $Content/ValidationBanner
@onready var _team_name_edit: LineEdit = $Content/NameRow/TeamNameEdit
@onready var _members_list: VBoxContainer = $Content/ScrollContainer/MembersList
@onready var _add_monster_button: Button = $Content/AddMonsterButton
@onready var _monster_picker: MonsterPickerDialog = $MonsterPickerDialog

func _ready() -> void:
	_team_name_edit.text_submitted.connect(_on_name_submitted)
	_team_name_edit.focus_exited.connect(_on_name_focus_exited)
	_add_monster_button.pressed.connect(_on_add_monster_pressed)
	_monster_picker.species_chosen.connect(_on_species_chosen)
	load_team("")

func setup(p_roster: TeamRosterManager, p_monster_db: MonsterDatabase, p_skill_db: SkillDatabase, p_skillset_db: SkillSetDatabase) -> void:
	roster = p_roster
	monster_db = p_monster_db
	skill_db = p_skill_db
	skillset_db = p_skillset_db
	_monster_picker.setup(monster_db)

## "" means "no team selected" — shows the empty state.
func load_team(team_id: String) -> void:
	current_team = null if team_id.is_empty() else roster.get_team(team_id)

	if current_team == null:
		_content.visible = false
		_empty_label.visible = true
		return

	_content.visible = true
	_empty_label.visible = false
	_team_name_edit.text = current_team.team_name
	_rebuild_rows()
	_update_validation_banner()

func _rebuild_rows() -> void:
	# remove_child() first: queue_free() alone defers actual removal to end
	# of frame, so a second _rebuild_rows() call in the same frame would
	# still see the "old" children via get_children().
	for child in _members_list.get_children():
		_members_list.remove_child(child)
		child.queue_free()
	for i in range(current_team.members.size()):
		var row: TeamMemberRow = TeamMemberRowScene.instantiate()
		_members_list.add_child(row)
		row.setup(current_team.members[i], i, monster_db, skill_db, skillset_db)
		row.loadout_edited.connect(_on_row_loadout_edited)
		row.remove_requested.connect(_on_row_remove_requested.bind(row))
		row.reorder_requested.connect(_on_row_reorder_requested)

func _update_validation_banner() -> void:
	var issue_count := 0
	for member in current_team.members:
		if not roster.validate_member(member, monster_db, skillset_db).is_empty():
			issue_count += 1
	_validation_banner.visible = issue_count > 0
	if issue_count > 0:
		_validation_banner.text = "This team has %d unresolved issue(s) — see flagged rows below." % issue_count

func _save_and_notify() -> void:
	roster.save_team(current_team)
	team_updated.emit(current_team)

func _on_name_submitted(new_text: String) -> void:
	_apply_name(new_text)

func _on_name_focus_exited() -> void:
	_apply_name(_team_name_edit.text)

func _apply_name(new_text: String) -> void:
	if current_team == null or current_team.team_name == new_text:
		return
	current_team.team_name = new_text
	_save_and_notify()

func _on_row_loadout_edited() -> void:
	_save_and_notify()
	_update_validation_banner()

func _on_row_remove_requested(row: TeamMemberRow) -> void:
	if current_team == null:
		return
	roster.remove_member(current_team, row.member_index)
	_save_and_notify()
	_rebuild_rows()
	_update_validation_banner()

func _on_row_reorder_requested(from_index: int, to_index: int) -> void:
	if current_team == null:
		return
	roster.move_member(current_team, from_index, to_index)
	roster.save_team(current_team)
	_rebuild_rows()
	# No team_updated emit — the team list panel doesn't display member order.

func _on_add_monster_pressed() -> void:
	_monster_picker.popup_centered()

func _on_species_chosen(species_id: String) -> void:
	if current_team == null:
		return
	var species := monster_db.get_species(species_id)
	var loadout := MonsterLoadout.new()
	loadout.species_id = species_id
	loadout.equipped_skill_ids = species.starting_skill_ids.duplicate() if species != null else []
	loadout.skill_point_allocation = {}
	roster.add_member(current_team, loadout)
	_save_and_notify()
	_rebuild_rows()
	_update_validation_banner()
