class_name BattleSetupScreen
extends Control

## Pick two saved teams and start a local two-window-plus-a-tab duel:
## side_a's view becomes a new tab in whatever MainShell hosts the caller
## (see battle_ready below), and a second real OS Window is spawned for
## side_b -- one process, one BattleController shared by both, no
## networking involved.
##
## Instantiated as an overlay ON TOP of whatever screen requested it (see
## TeamBuilderScreen._on_battle_pressed) rather than via change_scene_to_file
## -- DimBackground is the only "background" this scene draws, so the
## screen underneath stays alive and visible, just dimmed, and Back can
## return to it instantly without a scene reload.

signal back_requested()
## Carries the fully set-up side_a BattleSideView (see _on_start_pressed) up
## to whoever should host it -- this screen has no opinion on HOW it's
## shown (a new tab today, something else tomorrow), just that it's ready.
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

	var view_a: BattleSideView = BattleSideViewScene.instantiate()
	# Parented to self first purely so _ready() runs (setup() relies on its
	# own @onready node references) -- handed off to whatever hosts the new
	# tab immediately after, via remove_child() (detach, don't free).
	add_child(view_a)
	view_a.setup(controller, "side_a", skill_db)
	remove_child(view_a)
	battle_ready.emit(view_a, "vs %s" % team_b.team_name)
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
	# side_b's own window is self-contained -- its result panel's Back button
	# should just close this window, not touch the main window's own tabs
	# (previously it accidentally reloaded the main window's whole scene).
	view_b.close_requested.connect(window.queue_free)
