class_name BattleSetupScreen
extends Control

## Pick two saved teams and start a local hotseat duel: BOTH side_a's and
## side_b's views become their own tabs in whatever MainShell hosts the
## caller (see battle_ready below) -- one process, one BattleController
## shared by both, no networking, no second OS window. Switch between "my
## turn"/"their turn" the same way you'd switch to Home: click the tab.
## (An earlier version spawned a genuinely separate OS Window for side_b --
## dropped because it was never part of any tab bar at all, so whichever
## window you happened to be looking at when it wasn't the main one had no
## way back to Home no matter how many times the main window's own tab
## behavior got fixed. See wiki/log.md.)
##
## Instantiated as an overlay ON TOP of whatever screen requested it (see
## TeamBuilderScreen._on_battle_pressed) rather than via change_scene_to_file
## -- DimBackground is the only "background" this scene draws, so the
## screen underneath stays alive and visible, just dimmed, and Back can
## return to it instantly without a scene reload.

signal back_requested()
## Carries one fully set-up BattleSideView (see _on_start_pressed, fired
## once per side) up to whoever should host it -- this screen has no
## opinion on HOW it's shown (a new tab today, something else tomorrow),
## just that it's ready.
signal battle_ready(view: Control, tab_title: String)

const BattleSideViewScene := preload("res://ui/battle/battle_side_view.tscn")

var roster: TeamRosterManager
var monster_db: MonsterDatabase
var skill_db: SkillDatabase
var trait_db: TraitDatabase

var _teams: Array[SavedTeam] = []

@onready var _team_a_option: OptionButton = $CenterContainer/Panel/VBoxContainer/TeamARow/TeamAOption
@onready var _team_b_option: OptionButton = $CenterContainer/Panel/VBoxContainer/TeamBRow/TeamBOption
@onready var _back_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonsRow/BackButton
@onready var _start_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonsRow/StartButton
@onready var _error_label: Label = $CenterContainer/Panel/VBoxContainer/ErrorLabel

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
	_back_button.pressed.connect(_on_back_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_update_start_enabled()

func _on_back_pressed() -> void:
	back_requested.emit()
	queue_free()

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

	# Both sides become tabs in the same MainShell -- parented to self first
	# purely so _ready() runs (setup() relies on its own @onready node
	# references), then handed off via remove_child() (detach, don't free).
	var view_a: BattleSideView = BattleSideViewScene.instantiate()
	add_child(view_a)
	view_a.setup(controller, "side_a", skill_db)
	remove_child(view_a)

	var view_b: BattleSideView = BattleSideViewScene.instantiate()
	add_child(view_b)
	view_b.setup(controller, "side_b", skill_db)
	remove_child(view_b)

	battle_ready.emit(view_a, "P1: vs %s" % team_b.team_name)
	battle_ready.emit(view_b, "P2: vs %s" % team_a.team_name)
	queue_free()
