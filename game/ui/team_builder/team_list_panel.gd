class_name TeamListPanel
extends PanelContainer

## Team-level CRUD + import/export. Never touches MonsterDatabase/SkillDatabase
## — only team_roster_manager, since it only cares about which team is
## selected, not what's inside one.

signal team_selected(team_id: String)

var roster: TeamRosterManager
var _selected_team_id: String = ""

@onready var _teams_list: ItemList = $VBoxContainer/TeamsList
@onready var _new_button: Button = $VBoxContainer/CrudRow/NewButton
@onready var _duplicate_button: Button = $VBoxContainer/CrudRow/DuplicateButton
@onready var _delete_button: Button = $VBoxContainer/CrudRow/DeleteButton
@onready var _import_button: Button = $VBoxContainer/IoRow/ImportButton
@onready var _export_button: Button = $VBoxContainer/IoRow/ExportButton
@onready var _delete_confirm: ConfirmationDialog = $DeleteConfirmDialog
@onready var _import_dialog: FileDialog = $ImportDialog
@onready var _export_dialog: FileDialog = $ExportDialog

func _ready() -> void:
	_teams_list.item_selected.connect(_on_item_selected)
	_new_button.pressed.connect(_on_new_pressed)
	_duplicate_button.pressed.connect(_on_duplicate_pressed)
	_delete_button.pressed.connect(_on_delete_pressed)
	_import_button.pressed.connect(_on_import_pressed)
	_export_button.pressed.connect(_on_export_pressed)
	_delete_confirm.confirmed.connect(_on_delete_confirmed)
	_import_dialog.file_selected.connect(_on_import_file_selected)
	_export_dialog.file_selected.connect(_on_export_file_selected)
	_update_button_states()

func setup(p_roster: TeamRosterManager) -> void:
	roster = p_roster

func refresh_list() -> void:
	_teams_list.clear()
	var reselect_index := -1
	for team in roster.list_teams():
		var idx := _teams_list.add_item(team.team_name)
		_teams_list.set_item_metadata(idx, team.id)
		if team.id == _selected_team_id:
			reselect_index = idx

	if reselect_index >= 0:
		_teams_list.select(reselect_index)
	else:
		_selected_team_id = ""
	_update_button_states()

func _update_button_states() -> void:
	var has_selection := not _selected_team_id.is_empty()
	_duplicate_button.disabled = not has_selection
	_delete_button.disabled = not has_selection
	_export_button.disabled = not has_selection

func _on_item_selected(index: int) -> void:
	_selected_team_id = _teams_list.get_item_metadata(index)
	_update_button_states()
	team_selected.emit(_selected_team_id)

func _on_new_pressed() -> void:
	var team := roster.create_team("New Team")
	_selected_team_id = team.id
	refresh_list()
	team_selected.emit(_selected_team_id)

func _on_duplicate_pressed() -> void:
	if _selected_team_id.is_empty():
		return
	var team := roster.duplicate_team(_selected_team_id)
	if team == null:
		return
	_selected_team_id = team.id
	refresh_list()
	team_selected.emit(_selected_team_id)

func _on_delete_pressed() -> void:
	if _selected_team_id.is_empty():
		return
	var team := roster.get_team(_selected_team_id)
	var team_name := team.team_name if team != null else _selected_team_id
	_delete_confirm.dialog_text = "Delete team '%s'? This cannot be undone." % team_name
	_delete_confirm.popup_centered()

func _on_delete_confirmed() -> void:
	if _selected_team_id.is_empty():
		return
	roster.delete_team(_selected_team_id)
	_selected_team_id = ""
	refresh_list()
	team_selected.emit("")

func _on_import_pressed() -> void:
	_import_dialog.popup_centered_ratio()

func _on_import_file_selected(path: String) -> void:
	var team := roster.import_team_from_file(path)
	if team == null:
		return
	_selected_team_id = team.id
	refresh_list()
	team_selected.emit(_selected_team_id)

func _on_export_pressed() -> void:
	if _selected_team_id.is_empty():
		return
	_export_dialog.popup_centered_ratio()

func _on_export_file_selected(path: String) -> void:
	if _selected_team_id.is_empty():
		return
	var team := roster.get_team(_selected_team_id)
	if team != null:
		roster.export_team_to_file(team, path)
