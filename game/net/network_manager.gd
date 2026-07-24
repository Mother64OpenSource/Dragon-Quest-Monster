class_name NetworkManager
extends Node

## Autoload singleton (see project.godot's [autoload] section) -- owns the
## multiplayer connection for online 1v1 play so it survives the scene
## change from NetworkSetupScreen to the actual battle. This node only
## relays small handshake/action messages over Godot's high-level
## multiplayer RPC system; it has no battle logic of its own.
## NetworkBattleRelay (game/net/network_battle_relay.gd) is what actually
## wires these signals to a BattleController -- and needs zero changes for
## any of the three modes below, since it only ever depends on `is_host`
## and the public signals/methods here, never on how a message got there.
##
## Three modes, one script (all sharing this same "Network" autoload path,
## which Godot's RPC checksum/NodePath matching requires -- see
## wiki/log.md's Milestone 9 entry for why a genuinely separate relay
## project would have to hand-replicate this whole RPC surface forever with
## no compiler to catch drift):
##
## - DIRECT: the original transport (Milestones 7-8). One player's game
##   calls host_game() (ENet server, briefly listens for a connection), the
##   other calls join_game() (ENet client). Needs a port open on the host's
##   router -- fine for the same LAN, not for two friends on separate
##   networks.
## - RELAY_CLIENT: both players instead connect *outward* over WebSockets
##   to a small always-on relay (see RELAY_SERVER below), matched by a room
##   code one of them makes up and shares. Sidesteps NAT/port-forwarding
##   entirely, the same trick Pokemon Showdown uses (both players connect
##   out to a permanent server) -- except the relay here is a dumb pipe,
##   not a battle simulator; each client still runs its own local,
##   deterministic BattleController exactly as in DIRECT mode.
## - RELAY_SERVER: this same script, run headlessly on a small always-on
##   host (see game/net/run_relay_server.gd) with `--relay-server` on the
##   command line. Delegates all actual room-matching/forwarding logic to
##   RelayServerLogic (game/net/relay_server_logic.gd), which has zero
##   dependency on `multiplayer`/RPC/sockets and is what's headlessly
##   tested -- this script is just the thin RPC-facing glue around it.

signal connection_established()
signal connection_failed()
## Unified: fires whenever the opponent is unreachable, whatever the
## reason -- in DIRECT mode, the joiner leaving (peer_disconnected) or the
## host leaving (server_disconnected); in RELAY_CLIENT mode, the opponent
## explicitly leaving their room (_rpc_opponent_left) or the relay itself
## going down (server_disconnected). Callers don't need to know which.
signal opponent_disconnected()
signal team_received(team_dict: Dictionary)
signal seed_received(seed_value: int)
signal action_received(side: String, slot: int, kind: String, payload: Dictionary)
## RELAY_CLIENT only -- e.g. the room code you tried is already in use.
signal relay_room_error(message: String)

const DEFAULT_RELAY_PORT := 27931

enum Mode { DIRECT, RELAY_CLIENT, RELAY_SERVER }

var is_host: bool = false
var _mode: Mode = Mode.DIRECT
var _pending_room_code: String = ""
var _relay_logic: RelayServerLogic = null

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--relay-server"):
		_start_as_relay_server()
		return

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _start_as_relay_server() -> void:
	_mode = Mode.RELAY_SERVER
	_relay_logic = RelayServerLogic.new(_send_to_peer)
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(_relay_port_from_args())
	if err != OK:
		push_error("RelayServer: failed to listen on port %d (error %d)" % [_relay_port_from_args(), err])
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_disconnected.connect(_relay_logic.on_peer_disconnected)
	print("RelayServer: listening on port %d" % _relay_port_from_args())

func _relay_port_from_args() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--relay-port="):
			var value := arg.substr("--relay-port=".length())
			if value.is_valid_int():
				return int(value)
	return DEFAULT_RELAY_PORT

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
	_mode = Mode.DIRECT
	is_host = true
	return OK

func join_game(ip: String, port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_mode = Mode.DIRECT
	is_host = false
	return OK

## Connects outward to a relay server over WebSockets and asks to join (or
## create) a room identified by `room_code` -- no port-forwarding needed on
## either player's end, since both sides are always the ones dialing out.
## `relay_url` is a full ws://host:port or wss://host:port address.
func join_via_relay(relay_url: String, room_code: String) -> Error:
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(relay_url)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_mode = Mode.RELAY_CLIENT
	_pending_room_code = room_code
	return OK

func close_connection() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_mode = Mode.DIRECT
	is_host = false
	_pending_room_code = ""

func send_local_team(team_dict: Dictionary) -> void:
	if _mode == Mode.RELAY_CLIENT:
		rpc_id(1, "_rpc_relay_send", {"type": "team", "team": team_dict})
	else:
		rpc("_rpc_receive_team", team_dict)

func send_action(side: String, slot: int, kind: String, payload: Dictionary) -> void:
	if _mode == Mode.RELAY_CLIENT:
		rpc_id(1, "_rpc_relay_send", {"type": "action", "side": side, "slot": slot, "kind": kind, "payload": payload})
	else:
		rpc("_rpc_receive_action", side, slot, kind, payload)

## RELAY_SERVER only -- the Callable RelayServerLogic uses to actually
## deliver a message to a specific connected client. `args` is 0 or 1
## element for every RPC this relay ever sends; branching (rather than
## always passing a trailing null) avoids an argument-count mismatch on the
## zero-arg case (_rpc_opponent_left).
func _send_to_peer(peer_id: int, method: String, args: Array) -> void:
	if args.is_empty():
		rpc_id(peer_id, method)
	else:
		rpc_id(peer_id, method, args[0])

func _on_peer_connected(_id: int) -> void:
	if _mode == Mode.RELAY_CLIENT:
		# Reaching the relay isn't the same as being matched with an
		# opponent yet -- that only happens once _rpc_room_role_assigned
		# arrives, so connection_established doesn't fire here.
		rpc_id(1, "_rpc_join_room", _pending_room_code)
		return

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

## --- RELAY_CLIENT <-> RELAY_SERVER wire protocol below ---
## The relay (always peer id 1, the WebSocket server) never inspects
## envelope contents -- it's a dumb pipe, forwarding whatever one matched
## peer sends to the other. Client-facing methods below unpack the same
## envelope shape into this script's existing public signals, so
## NetworkBattleRelay/NetworkSetupScreen never need to know a relay was
## involved at all.

## client -> relay: join (or create) a room.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_join_room(room_code: String) -> void:
	if _relay_logic:
		_relay_logic.on_join_room(multiplayer.get_remote_sender_id(), room_code)

## client -> relay: forward this opaque envelope to whoever else is in my room.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_relay_send(envelope: Dictionary) -> void:
	if _relay_logic:
		_relay_logic.on_relay_send(multiplayer.get_remote_sender_id(), envelope)

## relay -> client: "authority" since the relay (peer 1) is the only one
## that ever calls this -- a client can't spoof its own role.
@rpc("authority", "call_remote", "reliable")
func _rpc_room_role_assigned(side: String) -> void:
	is_host = (side == "side_a")
	connection_established.emit()
	if is_host:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		rpc_id(1, "_rpc_relay_send", {"type": "seed", "seed": rng.randi()})

## relay -> client: the actual team/seed/action payload, unpacked back into
## this script's normal public signals.
@rpc("authority", "call_remote", "reliable")
func _rpc_relay_deliver(envelope: Dictionary) -> void:
	match envelope.get("type", ""):
		"team":
			team_received.emit(envelope.get("team", {}))
		"seed":
			seed_received.emit(int(envelope.get("seed", 0)))
		"action":
			action_received.emit(
				envelope.get("side", ""),
				int(envelope.get("slot", -1)),
				envelope.get("kind", ""),
				envelope.get("payload", {})
			)

## relay -> client: my room partner disconnected from the relay (the relay
## is still up, so this client's own multiplayer.server_disconnected/
## peer_disconnected wouldn't otherwise fire -- the client never had a
## direct connection to its partner, only to the relay).
@rpc("authority", "call_remote", "reliable")
func _rpc_opponent_left() -> void:
	opponent_disconnected.emit()

## relay -> client: e.g. the room code requested is already taken.
@rpc("authority", "call_remote", "reliable")
func _rpc_room_error(message: String) -> void:
	relay_room_error.emit(message)
