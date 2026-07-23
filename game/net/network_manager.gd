class_name NetworkManager
extends Node

## Autoload singleton (see project.godot's [autoload] section) -- owns the
## ENetMultiplayerPeer connection for online 1v1 play so it survives the
## scene change from NetworkSetupScreen to the actual battle. Direct connect
## only: one player's game briefly listens for the connection for that match
## (create_server), the other connects to their IP (create_client) -- there
## is no separate always-on dedicated server process.
##
## This node only relays small handshake/action messages over Godot's
## high-level multiplayer RPC system; it has no battle logic of its own.
## NetworkBattleRelay (game/net/network_battle_relay.gd) is what actually
## wires these signals to a BattleController.

signal connection_established()
signal connection_failed()
## Unified: fires whether we were the host (joiner left, via
## peer_disconnected) or the joiner (host left, via server_disconnected) --
## callers don't need to know which role they were to react to it.
signal opponent_disconnected()
signal team_received(team_dict: Dictionary)
signal seed_received(seed_value: int)
signal action_received(side: String, slot: int, kind: String, payload: Dictionary)

var is_host: bool = false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

## max_clients=1 -- exactly one opponent, ever. This also means a plain
## broadcast rpc() (not rpc_id(...)) is always unambiguous: no third peer id
## can ever exist to broadcast to by mistake, and a joiner's peer id is
## server-assigned and not guaranteed to be any particular small integer, so
## there'd be nothing reliable to rpc_id() to anyway.
func host_game(port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	return OK

func join_game(ip: String, port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	return OK

func close_connection() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

func send_local_team(team_dict: Dictionary) -> void:
	rpc("_rpc_receive_team", team_dict)

func send_action(side: String, slot: int, kind: String, payload: Dictionary) -> void:
	rpc("_rpc_receive_action", side, slot, kind, payload)

func _on_peer_connected(_id: int) -> void:
	connection_established.emit()
	if is_host:
		# Picked here (not in _ready) since it must be freshly randomized per
		# match, right when an opponent actually shows up. This is the
		# one-time choice of *which* seed a battle will use -- distinct from
		# DeterministicRng's "never use bare randi/randf in battle sim code"
		# rule, which governs code that runs *inside* a battle's simulation,
		# not the code that picks the seed before any simulation exists.
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		rpc("_rpc_receive_seed", rng.randi())

func _on_connection_failed() -> void:
	connection_failed.emit()

func _on_peer_disconnected(_id: int) -> void:
	opponent_disconnected.emit()

func _on_server_disconnected() -> void:
	opponent_disconnected.emit()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_receive_team(team_dict: Dictionary) -> void:
	team_received.emit(team_dict)

## "authority" (not "any_peer"): a Node's multiplayer authority defaults to
## peer id 1 -- the host -- with no extra code, so this is real enforcement
## that only the host's seed is ever used, not just a followed convention. A
## joiner that tried to call this would be rejected on receipt.
##
## "call_local" (not "call_remote"): the host is the one calling rpc(...)
## here (see _on_peer_connected), and needs to end up knowing the seed value
## too -- it generated it, but generating it doesn't by itself store or emit
## it locally. call_local makes this same handler fire on the caller as well
## as the remote peer, so seed_received fires symmetrically on both sides
## from one rpc() call, and NetworkSetupScreen doesn't need to special-case
## "I'm the host, so I already know the seed some other way."
@rpc("authority", "call_local", "reliable")
func _rpc_receive_seed(seed_value: int) -> void:
	seed_received.emit(seed_value)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_receive_action(side: String, slot: int, kind: String, payload: Dictionary) -> void:
	action_received.emit(side, slot, kind, payload)
