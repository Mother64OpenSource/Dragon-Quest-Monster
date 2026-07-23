class_name BattleSetupScreen
extends Control

## Pick two saved teams and start a local two-window duel: the current
## window becomes side_a's view, and a second real OS Window is spawned for
## side_b -- one process, one BattleController shared by both, no
## networking involved.

const BattleSideViewScene := preload("res://ui/battle/battle_side_view.tscn")

var roster: TeamRosterManager
var monster_db: MonsterDatabase
var skill_db: SkillDatabase
var trait_db: TraitDatabase

var _teams: Array[SavedTeam] = []

@onready var _team_a_option: OptionButton = $VBoxContainer/TeamARow/TeamAOption
@onready var _team_b_option: OptionButton = $VBoxContainer/TeamBRow/TeamBOption
@onready var _start_button: Button = $VBoxContainer/StartButton
@onready var _error_label: Label = $VBoxContainer/ErrorLabel

func _ready() -> void:
	roster = TeamRosterManager.new()
	monster_db = MonsterDatabase.new()
	skill_db = SkillDatabase.new()
	trait_db = TraitDatabase.new()

	_teams = roster.list_teams()
	_populate_option(_team_a_option)
	_populate_option(_team_b_option)

	_team_a_option.item_selected.connect(_on_selection_changed)
	_team_b_option.item_selected.connect(_on_selection_changed)
	_start_button.pressed.connect(_on_start_pressed)
	_update_start_enabled()

func _populate_option(option: OptionButton) -> void:
	option.clear()
	for team in _teams:
		option.add_item("%s (%d members)" % [team.team_name, team.members.size()])
	if _teams.is_empty():
		option.add_item("No saved teams")
		option.disabled = true

func _on_selection_changed(_index: int) -> void:
	_update_start_enabled()

func _update_start_enabled() -> void:
	_error_label.text = ""
	if _teams.size() < 1:
		_start_button.disabled = true
		_error_label.text = "No saved teams yet — build one first."
		return
	var team_a := _teams[_team_a_option.selected]
	var team_b := _teams[_team_b_option.selected]
	if team_a.members.is_empty() or team_b.members.is_empty():
		_start_button.disabled = true
		_error_label.text = "Both teams need at least one monster."
		return
	_start_button.disabled = false

func _on_start_pressed() -> void:
	var team_a := _teams[_team_a_option.selected]
	var team_b := _teams[_team_b_option.selected]

	var instances_a := TeamToBattleBridge.build_team(team_a, "side_a", monster_db, skill_db, trait_db, 0)
	var instances_b := TeamToBattleBridge.build_team(team_b, "side_b", monster_db, skill_db, trait_db, team_a.members.size())

	if instances_a.is_empty() or instances_b.is_empty():
		_error_label.text = "Couldn't build one of the teams (unknown species?)."
		return

	var controller := BattleController.new(instances_a, instances_b, skill_db.skills_by_id)

	var view_a: BattleSideView = BattleSideViewScene.instantiate()
	get_tree().root.add_child(view_a)
	get_tree().current_scene = view_a
	view_a.setup(controller, "side_a", skill_db)
	queue_free()

	var window := Window.new()
	window.title = "Battle — %s" % team_b.team_name
	window.size = Vector2i(760, 640)
	# Explicit (not just relying on defaults) so it's a genuinely independent,
	# freely draggable/resizable OS window rather than pinned to the main one.
	window.unresizable = false
	window.borderless = false
	window.exclusive = false
	window.transient = false
	window.always_on_top = false
	# Offset from the main window so it doesn't spawn stacked exactly on top
	# of it (which can look like "the window won't move" when really it's
	# just hidden directly underneath the other one).
	var main_pos := DisplayServer.window_get_position(DisplayServer.MAIN_WINDOW_ID)
	var main_size := DisplayServer.window_get_size(DisplayServer.MAIN_WINDOW_ID)
	window.position = main_pos + Vector2i(main_size.x + 24, 0)

	var view_b: BattleSideView = BattleSideViewScene.instantiate()
	window.add_child(view_b)
	get_tree().root.add_child(window)
	window.show()
	view_b.setup(controller, "side_b", skill_db)
