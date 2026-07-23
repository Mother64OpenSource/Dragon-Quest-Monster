class_name FakeNetworkManager
extends RefCounted

## Test double standing in for game/net/network_manager.gd -- simulates an
## instantaneous, always-delivered network between exactly two fakes (set
## `peer` post-construction to point at the other one) with zero real ENet
## sockets, no SceneTree, no multiplayer peer at all. NetworkBattleRelay only
## ever calls `.send_action(...)` and listens to `action_received`, so a
## fake exposing just those two is a complete stand-in for its purposes.

signal action_received(side: String, slot: int, kind: String, payload: Dictionary)

var peer: FakeNetworkManager
var send_count: int = 0

func send_action(side: String, slot: int, kind: String, payload: Dictionary) -> void:
	send_count += 1
	peer.action_received.emit(side, slot, kind, payload)
