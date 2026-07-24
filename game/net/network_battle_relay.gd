class_name NetworkBattleRelay
extends RefCounted

## Bridges one local BattleController to a network peer -- forwards the
## local player's own submissions out, and replays the peer's submissions
## into the local controller for the *other* side. Both peers in an online
## match run this same class over their own local BattleController; since
## the engine is fully deterministic given the same seed + same two teams +
## the same set of submitted actions (see wiki/log.md's M1 determinism
## notes), both controllers independently arrive at identical results no
## matter which peer's action for a round actually resolves the turn first.
##
## `network` is intentionally untyped rather than `: NetworkManager` --
## lets tests wire in a lightweight fake network double with zero real
## sockets, no scene tree, and no ENet peer at all (see
## network_relay_test_runner.gd), while production code passes the real
## autoload singleton.

var _controller: BattleController
var _network
var _local_side: String

func _init(controller: BattleController, network, local_side: String) -> void:
	_controller = controller
	_network = network
	_local_side = local_side
	_controller.action_submitted.connect(_on_local_action_submitted)
	_network.action_received.connect(_on_remote_action_received)

## Fires for every submission on this controller, regardless of origin.
## Only forward the ones that are actually ours to forward: a submission for
## the *other* side only ever happens because _on_remote_action_received
## just replayed one that arrived over the network -- forwarding that back
## out would echo it forever.
func _on_local_action_submitted(side: String, slot: int, kind: String, payload: Dictionary) -> void:
	if side != _local_side:
		return
	_network.send_action(side, slot, kind, payload)

func _on_remote_action_received(side: String, slot: int, kind: String, payload: Dictionary) -> void:
	match kind:
		"fight":
			_controller.submit_fight(side, slot, payload.get("skill_id", ""), int(payload.get("target_instance_id", -1)))
		"swap":
			_controller.submit_swap(side, slot, int(payload.get("bench_instance_id", -1)))
		"forfeit":
			_controller.forfeit(side)
		"defend":
			_controller.submit_defend(side, slot)
