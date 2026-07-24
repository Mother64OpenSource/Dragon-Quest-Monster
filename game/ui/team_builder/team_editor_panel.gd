class_name TeamEditorPanel
extends PanelContainer

## Shows the currently selected team's name + members, handles all
## member-level mutation (add/remove/reorder/edit) and persists via the
## injected TeamRosterManager. Auto-saves after every discrete edit — no
## manual Save button (see Milestone 3 plan for rationale).
##
## Members render across two rows -- Main Party (the active battle lineup)
## and Second Party (the bench) -- each capped at 4 slot-points via
## TeamFormationLayout, not 4 monsters: a 2/3/4-slot monster consumes that
## many of its party's slot-points, matching how much room it actually
## takes up once deployed. A TeamMemberRow's own width scales with its
## slots cost (see team_member_row.gd), and any unused slot-points in a
## party render as one EmptyTeamSlot sized to the remainder, so dragging a
## member onto it (real drag-and-drop can't be exercised headlessly, see
## the M3 plan -- verified manually) always means "move to the end of the
## list," regardless of exactly where in the remainder you drop.
##
## Adding a new monster is rejected outright if it wouldn't fit in either
## party (checked via TeamFormationLayout before it's ever added).
## Reordering an already-valid team is never blocked that way -- since
## TeamFormationLayout's packing is order-dependent (it mirrors
## BattleSetup's real greedy "skip what doesn't fit, keep scanning"
## algorithm), a drag COULD in principle produce an arrangement that
## doesn't fit either party even though some other order of the same
## members would; that surfaces as the Overflow row/banner instead of
## silently reverting or blocking the drag (see wiki/log.md).

signal team_updated(team: SavedTeam)

const TeamMemberRowScene := preload("res://ui/team_builder/team_member_row.tscn")
const EmptyTeamSlotScene := preload("res://ui/team_builder/empty_team_slot.tscn")

var roster: TeamRosterManager
var monster_db: MonsterDatabase
var skill_db: SkillDatabase
var skillset_db: SkillSetDatabase
var trait_db: TraitDatabase
var current_team: SavedTeam = null

@onready var _content: Control = $Content
@onready var _empty_label: Label = $EmptyStateLabel
@onready var _validation_banner: Label = $Content/ValidationBanner
@onready var _team_name_edit: LineEdit = $Content/NameRow/TeamNameEdit
@onready var _main_party_row: HBoxContainer = $Content/ScrollContainer/Parties/MainPartyRow
@onready var _second_party_row: HBoxContainer = $Content/ScrollContainer/Parties/SecondPartyRow
@onready var _overflow_label: Label = $Content/ScrollContainer/Parties/OverflowLabel
@onready var _overflow_row: HBoxContainer = $Content/ScrollContainer/Parties/OverflowRow
@onready var _add_monster_button: Button = $Content/AddMonsterButton
@onready var _monster_picker: MonsterPickerDialog = $MonsterPickerDialog

func _ready() -> void:
	_team_name_edit.text_submitted.connect(_on_name_submitted)
	_team_name_edit.focus_exited.connect(_on_name_focus_exited)
	_add_monster_button.pressed.connect(_on_add_monster_pressed)
	_monster_picker.species_chosen.connect(_on_species_chosen)
	load_team("")

func setup(p_roster: TeamRosterManager, p_monster_db: MonsterDatabase, p_skill_db: SkillDatabase, p_skillset_db: SkillSetDatabase, p_trait_db: TraitDatabase) -> void:
	roster = p_roster
	monster_db = p_monster_db
	skill_db = p_skill_db
	skillset_db = p_skillset_db
	trait_db = p_trait_db
	_monster_picker.setup(monster_db, trait_db)

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
	_clear_container(_main_party_row)
	_clear_container(_second_party_row)
	_clear_container(_overflow_row)

	var layout := TeamFormationLayout.compute(current_team.members, monster_db)

	for loadout in layout["main_party"]:
		_add_row(_main_party_row, loadout)
	var main_remaining: int = TeamFormationLayout.PARTY_CAPACITY - int(layout["main_used"])
	if main_remaining > 0:
		_add_empty_slot(_main_party_row, main_remaining)

	for loadout in layout["second_party"]:
		_add_row(_second_party_row, loadout)
	var second_remaining: int = TeamFormationLayout.PARTY_CAPACITY - int(layout["second_used"])
	if second_remaining > 0:
		_add_empty_slot(_second_party_row, second_remaining)

	var overflow: Array = layout["overflow"]
	for loadout in overflow:
		_add_row(_overflow_row, loadout)
	_overflow_label.visible = not overflow.is_empty()
	_overflow_row.visible = not overflow.is_empty()

func _add_row(parent: HBoxContainer, loadout: MonsterLoadout) -> void:
	var row: TeamMemberRow = TeamMemberRowScene.instantiate()
	parent.add_child(row)
	# The row's own index into TeamMemberRow.member_index/drag data must be
	# its REAL position in current_team.members (used for removal/reorder),
	# not its position within whichever party bucket it landed in --
	# TeamFormationLayout hands back the same loadout object references, so
	# a reference-identity find() recovers the real index cheaply.
	var real_index := current_team.members.find(loadout)
	row.setup(loadout, real_index, monster_db, skill_db, skillset_db, trait_db)
	row.loadout_edited.connect(_on_row_loadout_edited)
	row.remove_requested.connect(_on_row_remove_requested.bind(row))
	row.reorder_requested.connect(_on_row_reorder_requested)

func _add_empty_slot(parent: HBoxContainer, space_units: int) -> void:
	var empty_slot: EmptyTeamSlot = EmptyTeamSlotScene.instantiate()
	parent.add_child(empty_slot)
	empty_slot.configure(space_units)
	empty_slot.member_dropped.connect(_on_empty_slot_member_dropped)

func _clear_container(container: Container) -> void:
	# remove_child() first: queue_free() alone defers actual removal to end
	# of frame, so a second rebuild in the same frame would still see the
	# "old" children via get_children().
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

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

## Dropping a member onto a party's empty remainder means "send it to the
## end of the list" (see EmptyTeamSlot) -- the last real member's own
## index, since move_member() reorders relative to the CURRENT array.
func _on_empty_slot_member_dropped(from_index: int) -> void:
	if current_team == null or current_team.members.is_empty():
		return
	_on_row_reorder_requested(from_index, current_team.members.size() - 1)

func _on_add_monster_pressed() -> void:
	if current_team == null:
		return
	_monster_picker.popup_centered()

## Whether it fits depends on the chosen species' own slots cost, which
## isn't known until the picker returns one -- so unlike the old flat
## 8-monster cap, this can't be pre-checked by disabling the Add button;
## it's rejected here instead, after building the candidate loadout.
func _on_species_chosen(species_id: String) -> void:
	if current_team == null:
		return
	var species := monster_db.get_species(species_id)
	var loadout := MonsterLoadout.new()
	loadout.species_id = species_id
	loadout.equipped_skill_ids = species.starting_skill_ids.duplicate() if species != null else []
	loadout.skill_point_allocation = {}

	var candidate_members := current_team.members.duplicate()
	candidate_members.append(loadout)
	var layout := TeamFormationLayout.compute(candidate_members, monster_db)
	var overflow: Array = layout["overflow"]
	if overflow.has(loadout):
		return

	roster.add_member(current_team, loadout)
	_save_and_notify()
	_rebuild_rows()
	_update_validation_banner()
