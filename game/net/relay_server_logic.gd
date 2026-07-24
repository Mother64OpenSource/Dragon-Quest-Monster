class_name RelayServerLogic
extends RefCounted

## Pure room-matching/forwarding/cleanup logic for the WebSocket relay
## server (see game/net/network_manager.gd's RELAY_SERVER mode and
## game/net/run_relay_server.gd). Zero dependency on `multiplayer`/RPC/real
## sockets -- constructed with an injectable `send` Callable so this can be
## exercised headlessly with a fake in place of real peer delivery, the same
## way FakeNetworkManager already proves NetworkBattleRelay without ENet.
##
## Not to be confused with NetworkBattleRelay (game/net/network_battle_relay.gd),
## which bridges a BattleController to NetworkManager -- an unrelated,
## higher-level concept. This class only ever sees opaque envelopes and peer
## ids; it has no idea what a "battle" is.

## func(peer_id: int, method: String, args: Array) -> void
var _send: Callable

## room_code -> Array[int] of up to 2 peer ids, in join order.
var _rooms: Dictionary = {}
## peer_id -> room_code, for O(1) cleanup on disconnect.
var _peer_room: Dictionary = {}

func _init(send_callback: Callable) -> void:
	_send = send_callback

## First peer to join a code waits alone; the second completes the room and
## both get told their role -- first joiner is always "side_a", matching the
## same "host is side_a" fairness property the direct-connect transport
## already relies on (a role label, not new game logic, so nothing else
## needs re-checking for fairness here).
func on_join_room(peer_id: int, code: String) -> void:
	if not _rooms.has(code):
		_rooms[code] = [peer_id]
		_peer_room[peer_id] = code
		return

	var occupants: Array = _rooms[code]
	if occupants.size() >= 2:
		_send.call(peer_id, "_rpc_room_error", ["Room code already in use."])
		return

	occupants.append(peer_id)
	_peer_room[peer_id] = code
	_send.call(occupants[0], "_rpc_room_role_assigned", ["side_a"])
	_send.call(occupants[1], "_rpc_room_role_assigned", ["side_b"])

## The relay never inspects `envelope` -- it's an opaque passthrough tagged
## only by whatever "type" key the two clients agree on (team/seed/action).
func on_relay_send(sender_id: int, envelope: Dictionary) -> void:
	var partner := _partner_of(sender_id)
	if partner != -1:
		_send.call(partner, "_rpc_relay_deliver", [envelope])

func on_peer_disconnected(peer_id: int) -> void:
	var code = _peer_room.get(peer_id)
	if code == null:
		return
	var partner := _partner_of(peer_id)
	_rooms.erase(code)
	_peer_room.erase(peer_id)
	if partner != -1:
		_peer_room.erase(partner)
		_send.call(partner, "_rpc_opponent_left", [])

func _partner_of(peer_id: int) -> int:
	var code = _peer_room.get(peer_id)
	if code == null or not _rooms.has(code):
		return -1
	for id in _rooms[code]:
		if id != peer_id:
			return id
	return -1
