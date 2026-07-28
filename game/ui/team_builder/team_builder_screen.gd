class_name TeamBuilderScreen
extends Control

## Root screen: constructs the three shared collaborators once and relays
## the two cross-panel signals. Owns no team-mutation logic itself — that
## all lives in the panel that owns the concern (see the M3 plan).
##
## Lives as the permanent "Home" tab inside MainShell (see wiki/log.md) --
## starting a local battle no longer frees this screen; battle_launched()
## hands the built BattleSideView up to MainShell to open as its own tab,
## so Home stays alive and switchable-back-to the whole time, matching
## Pokemon Showdown's own Home-tab-plus-battle-tab layout.

signal battle_launched(view: Control, tab_title: String)

const BattleSetupScreenScene := preload("res://ui/battle/battle_setup_screen.tscn")

## Test seam: set before add_child() (i.e. before _ready() fires) to point
## the roster at an isolated directory instead of the real user://teams/.
## Empty string (the default) uses TeamRosterManager's own default.
var teams_dir_override: String = ""
## Same idea as teams_dir_override, for the single profile file instead of
## a directory of teams.
var profile_path_override: String = ""
## Same idea again, for the background preference file + copied-background
## directory (a pair, since BackgroundPreferenceManager owns both).
var background_pref_path_override: String = ""
var background_dir_override: String = ""

var monster_db: MonsterDatabase
var skill_db: SkillDatabase
var skillset_db: SkillSetDatabase
var trait_db: TraitDatabase
var weapon_db: WeaponDatabase
var blacksmith_db: BlacksmithDatabase
var roster: TeamRosterManager
var profile_manager: PlayerProfileManager
var background_pref_manager: BackgroundPreferenceManager
var _profile: PlayerProfile

@onready var _team_list_panel: TeamListPanel = $HSplitContainer/TeamListPanel
@onready var _team_editor_panel: TeamEditorPanel = $HSplitContainer/TeamEditorPanel
@onready var _battle_button: Button = $TopBarPanel/TopBar/BattleButton
@onready var _online_battle_button: Button = $TopBarPanel/TopBar/OnlineBattleButton
@onready var _profile_button: Button = $TopBarPanel/TopBar/ProfileButton
@onready var _scribble_art_check_box: CheckBox = $TopBarPanel/TopBar/ScribbleArtCheckBox
@onready var _change_background_button: Button = $TopBarPanel/TopBar/ChangeBackgroundButton
@onready var _profile_dialog: PlayerProfileDialog = $PlayerProfileDialog
@onready var _background_display: BackgroundDisplay = $BackgroundDisplay
## Looked up via get_node(), not the bare "ArtStylePreference" identifier --
## matches this project's own NetworkManager convention.
@onready var _art_style: ArtStylePreferenceManager = get_node("/root/ArtStylePreference")
@onready var _background_file_dialog: FileDialog = $BackgroundFileDialog

func _ready() -> void:
	_battle_button.pressed.connect(_on_battle_pressed)
	_online_battle_button.pressed.connect(_on_online_battle_pressed)
	_profile_button.pressed.connect(_on_profile_button_pressed)
	_change_background_button.pressed.connect(_on_change_background_pressed)
	_background_file_dialog.file_selected.connect(_on_background_file_selected)
	_scribble_art_check_box.button_pressed = _art_style.use_scribble_art
	_scribble_art_check_box.toggled.connect(_on_scribble_art_toggled)
	# Button doesn't auto-constrain icon size to something sane the way
	# ItemList does -- same class of issue already hit with Tree's monster
	# icons in MonsterPickerDialog (see wiki/log.md), just a different
	# Control this time.
	_profile_button.add_theme_constant_override("icon_max_width", 24)
	_profile_dialog.profile_saved.connect(_on_profile_saved)
	monster_db = MonsterDatabase.new()
	skill_db = SkillDatabase.new()
	skillset_db = SkillSetDatabase.new()
	trait_db = TraitDatabase.new()
	weapon_db = WeaponDatabase.new()
	blacksmith_db = BlacksmithDatabase.new()
	roster = TeamRosterManager.new(teams_dir_override) if not teams_dir_override.is_empty() else TeamRosterManager.new()
	profile_manager = PlayerProfileManager.new(profile_path_override) if not profile_path_override.is_empty() else PlayerProfileManager.new()
	var background_pref_path := background_pref_path_override if not background_pref_path_override.is_empty() else BackgroundPreferenceManager.DEFAULT_PREF_PATH
	var backgrounds_dir := background_dir_override if not background_dir_override.is_empty() else BackgroundPreferenceManager.DEFAULT_BACKGROUNDS_DIR
	background_pref_manager = BackgroundPreferenceManager.new(background_pref_path, backgrounds_dir)

	_team_list_panel.setup(roster)
	_team_editor_panel.setup(roster, monster_db, skill_db, skillset_db, trait_db, weapon_db, blacksmith_db)

	_team_list_panel.team_selected.connect(_on_team_selected)
	_team_editor_panel.team_updated.connect(_on_team_updated)

	_team_list_panel.refresh_list()

	_profile = profile_manager.get_or_create_profile()
	_refresh_profile_button()

	_background_display.set_background_path(background_pref_manager.get_preference().background_path)

func _on_team_selected(team_id: String) -> void:
	_team_editor_panel.load_team(team_id)

func _on_team_updated(_team: SavedTeam) -> void:
	_team_list_panel.refresh_list()

## Added as an overlay on top of this screen (not a scene change) so this
## screen stays alive and visible, dimmed, underneath -- Back just frees the
## overlay and we're right back here; Start Battle also just frees the
## overlay (see _on_overlay_battle_ready) -- this screen itself stays alive
## as the permanent Home tab.
func _on_battle_pressed() -> void:
	var overlay: BattleSetupScreen = BattleSetupScreenScene.instantiate()
	add_child(overlay)
	overlay.battle_ready.connect(_on_overlay_battle_ready)

func _on_overlay_battle_ready(view: Control, tab_title: String) -> void:
	battle_launched.emit(view, tab_title)

func _on_online_battle_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/online/network_setup_screen.tscn")

func _on_profile_button_pressed() -> void:
	_profile_dialog.setup(_profile, monster_db, trait_db)
	_profile_dialog.popup_centered()

func _on_profile_saved(profile: PlayerProfile) -> void:
	_profile = profile
	profile_manager.save_profile(_profile)
	_refresh_profile_button()

func _on_change_background_pressed() -> void:
	_background_file_dialog.popup_centered()

func _on_background_file_selected(path: String) -> void:
	var dest_path := background_pref_manager.set_background_from_external_file(path)
	if not dest_path.is_empty():
		_background_display.set_background_path(dest_path)

## Repaints everything on this screen that shows a monster icon and is
## still alive right now -- the profile button and whichever team is
## currently loaded in the editor panel. The monster picker dialog and
## every other screen (battle, network setup) don't need an explicit
## nudge here: they all resolve ArtStylePreference.resolve_sprite_path()
## fresh each time they're shown/rebuilt anyway.
func _on_scribble_art_toggled(pressed: bool) -> void:
	_art_style.set_use_scribble_art(pressed)
	_refresh_profile_button()
	_team_editor_panel.refresh()

func _refresh_profile_button() -> void:
	var species := monster_db.get_species(_profile.avatar_species_id)
	_profile_button.icon = _art_style.load_texture(species)
	_profile_button.text = _profile.player_name
