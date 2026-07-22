class_name TeamBuilderScreen
extends Control

## Root screen: constructs the three shared collaborators once and relays
## the two cross-panel signals. Owns no team-mutation logic itself — that
## all lives in the panel that owns the concern (see the M3 plan).

## Test seam: set before add_child() (i.e. before _ready() fires) to point
## the roster at an isolated directory instead of the real user://teams/.
## Empty string (the default) uses TeamRosterManager's own default.
var teams_dir_override: String = ""

var monster_db: MonsterDatabase
var skill_db: SkillDatabase
var roster: TeamRosterManager

@onready var _team_list_panel: TeamListPanel = $HSplitContainer/TeamListPanel
@onready var _team_editor_panel: TeamEditorPanel = $HSplitContainer/TeamEditorPanel

func _ready() -> void:
	monster_db = MonsterDatabase.new()
	skill_db = SkillDatabase.new()
	roster = TeamRosterManager.new(teams_dir_override) if not teams_dir_override.is_empty() else TeamRosterManager.new()

	_team_list_panel.setup(roster)
	_team_editor_panel.setup(roster, monster_db, skill_db)

	_team_list_panel.team_selected.connect(_on_team_selected)
	_team_editor_panel.team_updated.connect(_on_team_updated)

	_team_list_panel.refresh_list()

func _on_team_selected(team_id: String) -> void:
	_team_editor_panel.load_team(team_id)

func _on_team_updated(_team: SavedTeam) -> void:
	_team_list_panel.refresh_list()
