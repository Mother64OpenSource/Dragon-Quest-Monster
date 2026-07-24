class_name NetworkRelayTestRunner
extends RefCounted

## Proves NetworkBattleRelay's forwarding/echo-prevention logic end-to-end
## without any real networking: two real BattleController instances (same
## seed, same two teams -- see network_lockstep_test_runner.gd for why that's
## sufficient for determinism), two real NetworkBattleRelays, and two
## FakeNetworkManager doubles wired to each other instead of a real
## NetworkManager/ENet peer.

const SEED := 2468013579

const SideViewScene := preload("res://ui/battle/battle_side_view.tscn")

var _all_passed := true

func run(tree: SceneTree) -> bool:
	_all_passed = true
	var monster_db := MonsterDatabase.new()
	var skill_db := SkillDatabase.new()
	var trait_db := TraitDatabase.new()

	_check_relay_end_to_end(monster_db, skill_db, trait_db)
	_check_forfeit_forwards_to_peer(monster_db, skill_db, trait_db)
	await _check_disconnect_message(tree, monster_db, skill_db, trait_db)

	if _all_passed:
		print("NetworkRelayTestRunner: ALL CHECKS PASSED")
	else:
		print("NetworkRelayTestRunner: SOME CHECKS FAILED")
	return _all_passed

func _make_team(team_name: String, entries: Array) -> SavedTeam:
	var team := SavedTeam.new()
	team.id = team_name
	team.team_name = team_name
	var members: Array[MonsterLoadout] = []
	for entry in entries:
		var loadout := MonsterLoadout.new()
		loadout.species_id = entry[0]
		var skill_ids: Array[String] = []
		for id in entry[1]:
			skill_ids.append(id)
		loadout.equipped_skill_ids = skill_ids
		members.append(loadout)
	team.members = members
	return team

func _build_controller(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase, team_a: SavedTeam, team_b: SavedTeam) -> BattleController:
	var instances_a := TeamToBattleBridge.build_team(team_a, "side_a", monster_db, skill_db, trait_db, 0)
	var instances_b := TeamToBattleBridge.build_team(team_b, "side_b", monster_db, skill_db, trait_db, team_a.members.size())
	return BattleController.new(instances_a, instances_b, skill_db.skills_by_id, SEED)

func _check_relay_end_to_end(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var team_a := _make_team("Relay A", [["slime", ["attack"]]])
	var team_b := _make_team("Relay B", [["golem", ["attack"]]])

	# controller_a/relay_a stand in for the "side_a" player's own machine;
	# controller_b/relay_b for the "side_b" player's. Each is a fully
	# independent local simulation of the *entire* battle (both sides), kept
	# in sync purely by relaying each player's own submissions to the other.
	var controller_a := _build_controller(monster_db, skill_db, trait_db, team_a, team_b)
	var controller_b := _build_controller(monster_db, skill_db, trait_db, team_a, team_b)

	var fake_a := FakeNetworkManager.new()
	var fake_b := FakeNetworkManager.new()
	fake_a.peer = fake_b
	fake_b.peer = fake_a

	var relay_a := NetworkBattleRelay.new(controller_a, fake_a, "side_a")
	var relay_b := NetworkBattleRelay.new(controller_b, fake_b, "side_b")

	var log_a: Array = []
	var log_b: Array = []
	controller_a.engine.get_event_bus().event_emitted.connect(func(event: BattleEvent) -> void: log_a.append(event.to_dict()))
	controller_b.engine.get_event_bus().event_emitted.connect(func(event: BattleEvent) -> void: log_b.append(event.to_dict()))

	# The side_a player submits their own action locally on their own controller.
	var a_target := controller_a.get_state().get_monster_at("side_b", 0)
	controller_a.submit_fight("side_a", 0, "attack", a_target.instance_id)

	_check("relay forwards a local side_a submission to the peer", fake_a.send_count == 1)
	_check("the peer's controller receives the replayed side_a action", controller_b.is_slot_submitted("side_a", 0))
	_check("the peer's relay does not echo the replayed action back", fake_b.send_count == 0)

	# The side_b player submits their own action locally on their own controller,
	# completing round 1 on both sides purely through the relay path.
	var b_target := controller_b.get_state().get_monster_at("side_a", 0)
	controller_b.submit_fight("side_b", 0, "attack", b_target.instance_id)

	_check("relay forwards a local side_b submission to the peer", fake_b.send_count == 1)
	# Both controllers' round 1 resolves as soon as this call delivers the
	# replayed side_b action to controller_a (its side_a slot was already
	# filled in by the earlier step) -- _submitted_slots gets reset for the
	# new round immediately on resolution, so check turn_number advanced
	# rather than the now-stale "is slot submitted" flag.
	_check("the first peer's controller receives the replayed side_b action and resolves round 1", controller_a.get_state().turn_number >= 1)
	_check("the first peer's relay still hasn't echoed anything extra", fake_a.send_count == 1)

	# Keep playing to completion, each "player" only ever submitting for
	# their own side on their own controller -- exactly what a real online
	# match's two separate processes would do.
	var turns := 0
	while (not controller_a.is_over() or not controller_b.is_over()) and turns < 100:
		if not controller_a.is_over() and not controller_a.is_slot_submitted("side_a", 0):
			var target_a := controller_a.get_state().get_monster_at("side_b", 0)
			controller_a.submit_fight("side_a", 0, "attack", target_a.instance_id)
		if not controller_b.is_over() and not controller_b.is_slot_submitted("side_b", 0):
			var target_b := controller_b.get_state().get_monster_at("side_a", 0)
			controller_b.submit_fight("side_b", 0, "attack", target_b.instance_id)
		turns += 1

	_check("both controllers reach battle_ended purely via the relay path", controller_a.is_over() and controller_b.is_over())
	_check("winner_side matches across both controllers", controller_a.get_state().winner_side == controller_b.get_state().winner_side)
	_check("event logs are identical end-to-end through the real relay code path", log_a == log_b and not log_a.is_empty())

## Forfeiting reuses BattleController's existing action_submitted plumbing
## (the same mechanism submit_fight/submit_swap already forward through) --
## this proves that reuse actually works end-to-end through a real relay,
## not just that the signal fires.
func _check_forfeit_forwards_to_peer(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var team_a := _make_team("Forfeit A", [["slime", ["attack"]]])
	var team_b := _make_team("Forfeit B", [["golem", ["attack"]]])

	var controller_a := _build_controller(monster_db, skill_db, trait_db, team_a, team_b)
	var controller_b := _build_controller(monster_db, skill_db, trait_db, team_a, team_b)

	var fake_a := FakeNetworkManager.new()
	var fake_b := FakeNetworkManager.new()
	fake_a.peer = fake_b
	fake_b.peer = fake_a

	# Kept in named vars, not discarded -- these are RefCounted, and with no
	# reference held anywhere they'd be freed almost immediately, silently
	# dropping the signal connections that make forwarding work at all.
	var relay_a := NetworkBattleRelay.new(controller_a, fake_a, "side_a")
	var relay_b := NetworkBattleRelay.new(controller_b, fake_b, "side_b")

	# The side_a player forfeits on their own machine/controller.
	controller_a.forfeit("side_a")

	_check("forfeiting ends the forfeiting player's own controller immediately", controller_a.is_over())
	_check("the forfeit is forwarded to the peer", fake_a.send_count == 1)
	_check("the peer's controller also ends, crediting the same winner", controller_b.is_over() and controller_b.get_state().winner_side == "side_b")
	_check("the peer's relay does not echo the forfeit back", fake_b.send_count == 0)

func _check_disconnect_message(tree: SceneTree, monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var team_a := _make_team("Disconnect A", [["slime", ["attack"]]])
	var team_b := _make_team("Disconnect B", [["golem", ["attack"]]])
	var controller := _build_controller(monster_db, skill_db, trait_db, team_a, team_b)

	var view: BattleSideView = SideViewScene.instantiate()
	tree.root.add_child(view)
	await tree.process_frame
	view.setup(controller, "side_a", skill_db)

	view.show_disconnect_message("Connection to your opponent was lost.")
	_check("show_disconnect_message reveals the result panel", view._result_panel.visible)
	_check("show_disconnect_message sets the expected text", view._result_label.text == "Connection to your opponent was lost.")

	view.queue_free()

func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		print("FAIL: %s" % label)
		_all_passed = false
