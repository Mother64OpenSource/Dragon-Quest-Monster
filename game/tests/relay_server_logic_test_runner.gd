class_name RelayServerLogicTestRunner
extends RefCounted

## Proves RelayServerLogic's room-matching/forwarding/cleanup logic in
## complete isolation -- no multiplayer/RPC/real sockets involved. A fake
## `send` Callable just records (peer_id, method, args) tuples, the same
## philosophy as FakeNetworkManager proving NetworkBattleRelay without ENet.

var _all_passed := true

func run() -> bool:
	_all_passed = true
	_check_first_joiner_is_side_a()
	_check_full_room_rejects_a_third_peer()
	_check_relay_send_delivers_to_partner_only()
	_check_solo_disconnect_clears_silently()
	_check_matched_disconnect_notifies_partner()

	if _all_passed:
		print("RelayServerLogicTestRunner: ALL CHECKS PASSED")
	else:
		print("RelayServerLogicTestRunner: SOME CHECKS FAILED")
	return _all_passed

## Returns [relay, sent_calls] -- sent_calls accumulates every
## {"peer_id":, "method":, "args":} tuple the relay ever sends.
func _new_relay() -> Array:
	var sent_calls: Array = []
	var fake_send := func(peer_id: int, method: String, args: Array) -> void:
		sent_calls.append({"peer_id": peer_id, "method": method, "args": args})
	var relay := RelayServerLogic.new(fake_send)
	return [relay, sent_calls]

func _calls_to(sent_calls: Array, peer_id: int) -> Array:
	var result: Array = []
	for call in sent_calls:
		if call["peer_id"] == peer_id:
			result.append(call)
	return result

## The fairness property this whole milestone depends on: whoever joins a
## room code first plays the same role "host" played in direct-connect mode
## ("side_a"), matching what battle_setup.gd/battle_state.gd/
## action_resolver.gd already confirmed is fair in Milestone 7-8.
func _check_first_joiner_is_side_a() -> void:
	var pair := _new_relay()
	var relay: RelayServerLogic = pair[0]
	var sent_calls: Array = pair[1]

	relay.on_join_room(10, "match-code")
	_check("first joiner gets no role yet (waiting alone)", _calls_to(sent_calls, 10).is_empty())

	relay.on_join_room(20, "match-code")
	var calls_10 := _calls_to(sent_calls, 10)
	var calls_20 := _calls_to(sent_calls, 20)
	_check("first joiner is told side_a once the room fills", calls_10.size() == 1 and calls_10[0]["method"] == "_rpc_room_role_assigned" and calls_10[0]["args"] == ["side_a"])
	_check("second joiner is told side_b", calls_20.size() == 1 and calls_20[0]["method"] == "_rpc_room_role_assigned" and calls_20[0]["args"] == ["side_b"])

func _check_full_room_rejects_a_third_peer() -> void:
	var pair := _new_relay()
	var relay: RelayServerLogic = pair[0]
	var sent_calls: Array = pair[1]

	relay.on_join_room(1, "full-code")
	relay.on_join_room(2, "full-code")
	sent_calls.clear()

	relay.on_join_room(3, "full-code")
	var calls_3 := _calls_to(sent_calls, 3)
	_check("a third peer joining a full room gets an error, not a role", calls_3.size() == 1 and calls_3[0]["method"] == "_rpc_room_error")
	_check("the original two occupants aren't re-notified", _calls_to(sent_calls, 1).is_empty() and _calls_to(sent_calls, 2).is_empty())

func _check_relay_send_delivers_to_partner_only() -> void:
	var pair := _new_relay()
	var relay: RelayServerLogic = pair[0]
	var sent_calls: Array = pair[1]

	relay.on_join_room(100, "send-code")
	relay.on_join_room(200, "send-code")
	sent_calls.clear()

	relay.on_relay_send(100, {"type": "team", "team": {"id": "example"}})
	var calls_100 := _calls_to(sent_calls, 100)
	var calls_200 := _calls_to(sent_calls, 200)
	_check("relay_send from one peer delivers to its partner", calls_200.size() == 1 and calls_200[0]["method"] == "_rpc_relay_deliver" and calls_200[0]["args"] == [{"type": "team", "team": {"id": "example"}}])
	_check("relay_send never echoes back to the sender", calls_100.is_empty())

func _check_solo_disconnect_clears_silently() -> void:
	var pair := _new_relay()
	var relay: RelayServerLogic = pair[0]
	var sent_calls: Array = pair[1]

	relay.on_join_room(5, "solo-code")
	sent_calls.clear()

	relay.on_peer_disconnected(5)
	_check("an unmatched peer disconnecting sends nothing to anyone", sent_calls.is_empty())

	# The room should be fully gone, not just missing its one occupant --
	# a fresh peer using the same code should start a brand new room.
	relay.on_join_room(6, "solo-code")
	_check("the vacated room can be reused as a fresh room afterward", _calls_to(sent_calls, 6).is_empty())

func _check_matched_disconnect_notifies_partner() -> void:
	var pair := _new_relay()
	var relay: RelayServerLogic = pair[0]
	var sent_calls: Array = pair[1]

	relay.on_join_room(7, "match-drop-code")
	relay.on_join_room(8, "match-drop-code")
	sent_calls.clear()

	relay.on_peer_disconnected(7)
	var calls_8 := _calls_to(sent_calls, 8)
	_check("the surviving partner is told the opponent left", calls_8.size() == 1 and calls_8[0]["method"] == "_rpc_opponent_left")

	sent_calls.clear()
	relay.on_relay_send(8, {"type": "action"})
	_check("the survivor's own bookkeeping is cleared too -- nothing delivers after both are gone", sent_calls.is_empty())

func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		print("FAIL: %s" % label)
		_all_passed = false
