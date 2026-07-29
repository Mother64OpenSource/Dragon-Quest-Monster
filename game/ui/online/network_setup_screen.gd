class_name NetworkSetupScreen
extends Control

## Host/Join UI for online 1v1 PvP (see game/net/network_manager.gd, the
## "Network" autoload) -- either a direct ENet connection (works on the same
## LAN, needs the host to open a port for internet play) or a WebSocket
## relay + room code (works over the real internet with no port-forwarding
## on either side, at the cost of needing a small always-on relay server
## somewhere -- see network_manager.gd's Mode enum and
## game/net/relay_server_logic.gd). Each machine picks its own locally-saved
## team; once both sides have exchanged team data and
## a shared seed (the host always generates and sends the seed), each peer
## independently builds both teams' MonsterInstance arrays via
## TeamToBattleBridge and launches its own BattleController -- kept in sync
## with the opponent purely by relaying submissions (see
## game/net/network_battle_relay.gd). Host is always side_a, joiner is
## always side_b (confirmed fair -- see wiki/log.md).
##
## Unlike the local 2-window flow (battle_setup_screen.gd), this only ever
## launches ONE BattleSideView: the opponent is a different physical machine,
## so there is nothing local to render for their side.

const BattleSideViewScene := preload("res://ui/battle/battle_side_view.tscn")
const DEFAULT_PORT := 27931

var roster: TeamRosterManager
var monster_db: MonsterDatabase
var skill_db: SkillDatabase
var trait_db: TraitDatabase
var skillset_db: SkillSetDatabase
var profile_manager: PlayerProfileManager

var _teams: Array[SavedTeam] = []
var _my_team: SavedTeam = null
var _my_team_dict: Dictionary = {}
var _opponent_team_dict: Dictionary = {}
var _my_profile: PlayerProfile
var _opponent_profile_dict: Dictionary = {}
var _shared_seed: int = -1
var _local_ready: bool = false
var _team_received: bool = false
var _profile_received: bool = false
var _seed_received: bool = false
var _battle_launched: bool = false
var _relay: NetworkBattleRelay = null

## Resolved via get_node() rather than referencing the bare autoload
## identifier "Network" directly -- keeps this script working identically
## whether it's running as part of a normal scene tree or instantiated
## directly by a headless test's custom SceneTree/MainLoop script, where an
## autoload's global identifier isn't guaranteed to be resolvable yet at
## parse time.
@onready var _network: NetworkManager = get_node("/root/Network")

@onready var _host_section: VBoxContainer = $VBoxContainer/HostSection
@onready var _port_edit: LineEdit = $VBoxContainer/HostSection/HostPortRow/PortEdit
@onready var _host_button: Button = $VBoxContainer/HostSection/HostButton
@onready var _local_ip_label: Label = $VBoxContainer/HostSection/LocalIpLabel
@onready var _join_section: VBoxContainer = $VBoxContainer/JoinSection
@onready var _ip_edit: LineEdit = $VBoxContainer/JoinSection/JoinIpRow/IpEdit
@onready var _join_port_edit: LineEdit = $VBoxContainer/JoinSection/JoinPortRow/JoinPortEdit
@onready var _join_button: Button = $VBoxContainer/JoinSection/JoinButton
@onready var _relay_section: VBoxContainer = $VBoxContainer/RelaySection
@onready var _relay_url_edit: LineEdit = $VBoxContainer/RelaySection/RelayUrlRow/RelayUrlEdit
@onready var _relay_code_edit: LineEdit = $VBoxContainer/RelaySection/RelayCodeRow/RelayCodeEdit
@onready var _relay_connect_button: Button = $VBoxContainer/RelaySection/RelayConnectButton
@onready var _status_label: Label = $VBoxContainer/StatusLabel
@onready var _team_pick_row: HBoxContainer = $VBoxContainer/TeamPickRow
@onready var _team_option: OptionButton = $VBoxContainer/TeamPickRow/TeamOption
@onready var _matchup_row: HBoxContainer = $VBoxContainer/MatchupRow
@onready var _you_icon: TextureRect = $VBoxContainer/MatchupRow/YouBox/YouIcon
@onready var _you_label: Label = $VBoxContainer/MatchupRow/YouBox/YouLabel
@onready var _opponent_icon: TextureRect = $VBoxContainer/MatchupRow/OpponentBox/OpponentIcon
@onready var _opponent_label: Label = $VBoxContainer/MatchupRow/OpponentBox/OpponentLabel
@onready var _ready_button: Button = $VBoxContainer/ReadyButton
@onready var _back_button: Button = $VBoxContainer/BackButton

func _ready() -> void:
	roster = TeamRosterManager.new()
	monster_db = MonsterDatabase.new()
	skill_db = SkillDatabase.new()
	trait_db = TraitDatabase.new()
	skillset_db = SkillSetDatabase.new()
	profile_manager = PlayerProfileManager.new()

	_teams = roster.list_teams()
	_populate_team_option()

	_my_profile = profile_manager.get_or_create_profile()
	_you_label.text = _my_profile.player_name
	_you_icon.texture = _load_avatar_icon(_my_profile.avatar_species_id)
	_opponent_label.text = "(waiting...)"

	_port_edit.text = str(DEFAULT_PORT)
	_join_port_edit.text = str(DEFAULT_PORT)
	_local_ip_label.text = (
		"Your local IP(s): %s\nFor internet play, forward this port on your router and share your public IP (found via your own router page or a \"what's my IP\" lookup)."
		% ", ".join(_ipv4_addresses())
	)

	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_relay_connect_button.pressed.connect(_on_relay_connect_pressed)
	_ready_button.pressed.connect(_on_ready_pressed)
	_back_button.pressed.connect(_on_back_pressed)

	_network.connection_established.connect(_on_connection_established)
	_network.connection_failed.connect(_on_connection_failed)
	_network.opponent_disconnected.connect(_on_opponent_disconnected)
	_network.team_received.connect(_on_team_received)
	_network.profile_received.connect(_on_profile_received)
	_network.seed_received.connect(_on_seed_received)
	_network.relay_room_error.connect(_on_relay_room_error)

	_team_pick_row.visible = false
	_matchup_row.visible = false
	_ready_button.visible = false
	_status_label.text = "Host a match, or join one."

## IP.get_local_addresses() returns every interface's address, IPv6 and
## link-local included -- overwhelming and mostly useless for "which
## address do I give my friend." A plain IPv4 address (has dots, no colons)
## is what ENetMultiplayerPeer.create_client() actually expects anyway.
func _ipv4_addresses() -> Array:
	var result: Array = []
	for address in IP.get_local_addresses():
		if address.contains(".") and not address.contains(":"):
			result.append(address)
	return result

func _populate_team_option() -> void:
	_team_option.clear()
	for team in _teams:
		_team_option.add_item("%s (%d members)" % [team.team_name, team.members.size()])
	if _teams.is_empty():
		_team_option.add_item("No saved teams")
		_team_option.disabled = true

func _on_host_pressed() -> void:
	var port := int(_port_edit.text) if _port_edit.text.is_valid_int() else DEFAULT_PORT
	var err := _network.host_game(port)
	if err != OK:
		_status_label.text = "Couldn't host on port %d (error %d)." % [port, err]
		return
	_status_label.text = "Hosting on port %d -- waiting for your opponent to join..." % port
	_set_connect_controls_enabled(false)

func _on_join_pressed() -> void:
	var port := int(_join_port_edit.text) if _join_port_edit.text.is_valid_int() else DEFAULT_PORT
	var ip := _ip_edit.text.strip_edges()
	if ip.is_empty():
		_status_label.text = "Enter the host's IP address first."
		return
	var err := _network.join_game(ip, port)
	if err != OK:
		_status_label.text = "Couldn't connect (error %d)." % err
		return
	_status_label.text = "Connecting to %s:%d..." % [ip, port]
	_set_connect_controls_enabled(false)

func _on_relay_connect_pressed() -> void:
	var url := _relay_url_edit.text.strip_edges()
	var code := _relay_code_edit.text.strip_edges()
	if url.is_empty() or code.is_empty():
		_status_label.text = "Enter both the relay address and a room code first."
		return
	var err := _network.join_via_relay(url, code)
	if err != OK:
		_status_label.text = "Couldn't reach the relay (error %d)." % err
		return
	_status_label.text = "Connecting to the relay..."
	_set_connect_controls_enabled(false)

func _on_relay_room_error(message: String) -> void:
	_status_label.text = message
	_set_connect_controls_enabled(true)

func _set_connect_controls_enabled(enabled: bool) -> void:
	_host_section.modulate.a = 1.0 if enabled else 0.5
	_join_section.modulate.a = 1.0 if enabled else 0.5
	_relay_section.modulate.a = 1.0 if enabled else 0.5
	_host_button.disabled = not enabled
	_join_button.disabled = not enabled
	_relay_connect_button.disabled = not enabled
	_port_edit.editable = enabled
	_ip_edit.editable = enabled
	_join_port_edit.editable = enabled
	_relay_url_edit.editable = enabled
	_relay_code_edit.editable = enabled

func _on_connection_established() -> void:
	if _teams.is_empty():
		_status_label.text = "Connected, but you have no saved teams -- build one first."
		return
	_status_label.text = "Connected! Pick your team and press Ready."
	_team_pick_row.visible = true
	_matchup_row.visible = true
	_ready_button.visible = true

func _on_connection_failed() -> void:
	_status_label.text = "Connection failed."
	_set_connect_controls_enabled(true)

func _on_opponent_disconnected() -> void:
	if _battle_launched:
		return  # the battle scene's own handler (wired in _launch_battle) takes over
	_status_label.text = "Your opponent disconnected."
	_team_pick_row.visible = false
	_matchup_row.visible = false
	_ready_button.visible = false
	_set_connect_controls_enabled(true)

func _on_ready_pressed() -> void:
	_my_team = _teams[_team_option.selected]
	_my_team_dict = SavedTeamLoader.to_dict(_my_team)
	_local_ready = true
	_ready_button.disabled = true
	_team_option.disabled = true
	_network.send_local_team(_my_team_dict)
	_network.send_local_profile(PlayerProfileLoader.to_dict(_my_profile))
	_status_label.text = "Waiting for your opponent..."
	_check_ready_to_start()

func _on_team_received(team_dict: Dictionary) -> void:
	_opponent_team_dict = team_dict
	_team_received = true
	_check_ready_to_start()

func _on_profile_received(profile_dict: Dictionary) -> void:
	_opponent_profile_dict = profile_dict
	_profile_received = true
	var opponent_profile := PlayerProfileLoader.load_from_dict(profile_dict)
	_opponent_label.text = opponent_profile.player_name
	_opponent_icon.texture = _load_avatar_icon(opponent_profile.avatar_species_id)
	_check_ready_to_start()

func _on_seed_received(seed_value: int) -> void:
	_shared_seed = seed_value
	_seed_received = true
	_check_ready_to_start()

## Readiness falls out of data already being exchanged for other reasons --
## no separate "both ready" handshake message is needed.
func _check_ready_to_start() -> void:
	if _battle_launched or not _local_ready or not _team_received or not _profile_received or not _seed_received:
		return
	_launch_battle()

func _load_avatar_icon(species_id: String) -> Texture2D:
	var species := monster_db.get_species(species_id)
	var art_style: ArtStylePreferenceManager = get_node("/root/ArtStylePreference")
	return art_style.load_texture(species)

func _launch_battle() -> void:
	_battle_launched = true

	var host_team_dict: Dictionary = _my_team_dict if _network.is_host else _opponent_team_dict
	var joiner_team_dict: Dictionary = _opponent_team_dict if _network.is_host else _my_team_dict
	var host_team := SavedTeamLoader.load_from_dict(host_team_dict)
	var joiner_team := SavedTeamLoader.load_from_dict(joiner_team_dict)

	var instances_a := TeamToBattleBridge.build_team(host_team, "side_a", monster_db, skill_db, trait_db, skillset_db, 0)
	var instances_b := TeamToBattleBridge.build_team(joiner_team, "side_b", monster_db, skill_db, trait_db, skillset_db, host_team.members.size())
	if instances_a.is_empty() or instances_b.is_empty():
		_status_label.text = "Couldn't build one of the teams (unknown species?)."
		_battle_launched = false
		return

	var controller := BattleController.new(instances_a, instances_b, skill_db.skills_by_id, _shared_seed)
	var my_side := "side_a" if _network.is_host else "side_b"
	_relay = NetworkBattleRelay.new(controller, _network, my_side)

	var opponent_name := PlayerProfileLoader.load_from_dict(_opponent_profile_dict).player_name

	var view: BattleSideView = BattleSideViewScene.instantiate()
	get_tree().root.add_child(view)
	get_tree().current_scene = view
	view.setup(controller, my_side, skill_db, opponent_name)
	# This screen's own current_scene-swap flow (unlike the local-battle path,
	# still out of scope for the tab-shell rework -- see wiki/log.md) means
	# view's result panel's Back button has nowhere to bubble up to on its
	# own; close_requested now needs an explicit listener here instead of
	# the old change_scene_to_file() battle_side_view.gd used to call itself.
	# A lambda capturing only the persistent /root/Network autoload, NOT a
	# bound method on self -- this screen queue_free()s itself a few lines
	# down, long before the player might actually press Back mid-battle, so
	# a Callable(self, ...) connection would already be silently severed by
	# the time it's needed (Godot auto-disconnects signals once either end
	# is freed).
	var network := _network
	var battle_music := get_node("/root/BattleMusic")
	view.close_requested.connect(func() -> void:
		network.close_connection()
		battle_music.battle_tab_closed()
		view.get_tree().change_scene_to_file("res://ui/shell/main_shell.tscn")
	)

	var handle_battle_disconnect := func() -> void:
		if is_instance_valid(view):
			view.show_disconnect_message("Connection to your opponent was lost.")
	_network.opponent_disconnected.connect(handle_battle_disconnect, CONNECT_ONE_SHOT)

	queue_free()

func _on_back_pressed() -> void:
	_network.close_connection()
	# Targets the tab shell (see wiki/log.md), not the bare TeamBuilderScreen
	# directly -- online battles still fully replace the scene tree rather
	# than getting their own tab (deliberately out of scope for that pass),
	# but "back" should still land you somewhere with the tab bar intact
	# rather than a stray screen with no way back to it at all.
	get_tree().change_scene_to_file("res://ui/shell/main_shell.tscn")
