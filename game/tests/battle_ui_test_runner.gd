class_name BattleUiTestRunner
extends RefCounted

## Milestone 5 (multi-slot grid battles) checks: the SavedTeam -> MonsterInstance
## bridge, BattleController's per-slot submit/resolve gating, explicit targeting,
## the Orders/swap-in command, a full battle running to completion, and
## BattleSideView rendering the right action buttons. Real Window/OS popup
## behavior and actually clicking through the grid/target-pick flow can't be
## exercised headlessly (see the M5 plan) -- that part is manual-only, verified
## via F5.

const SideViewScene := preload("res://ui/battle/battle_side_view.tscn")

var _all_passed := true
var _tree: SceneTree

func run(tree: SceneTree) -> bool:  # coroutine (awaits a frame internally)
	_all_passed = true
	_tree = tree

	var monster_db := MonsterDatabase.new()
	var skill_db := SkillDatabase.new()
	var trait_db := TraitDatabase.new()

	_check_bridge(monster_db, skill_db, trait_db)
	_check_controller_gating(monster_db, skill_db, trait_db)
	_check_explicit_targeting(monster_db, skill_db, trait_db)
	_check_full_battle(monster_db, skill_db, trait_db)
	_check_multi_slot(monster_db, skill_db, trait_db)
	_check_orders_swap(monster_db, skill_db, trait_db)
	_check_size_aware_packing(monster_db, skill_db, trait_db)
	await _check_side_view_rendering(monster_db, skill_db, trait_db)

	if _all_passed:
		print("BattleUiTestRunner: ALL CHECKS PASSED")
	else:
		print("BattleUiTestRunner: SOME CHECKS FAILED")
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

func _check_bridge(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var team := _make_team("Bridge Test", [["slime", ["attack", "frizz"]]])
	var instances := TeamToBattleBridge.build_team(team, "side_a", monster_db, skill_db, trait_db, 0)
	_check("bridge builds one instance per loadout", instances.size() == 1)
	_check("bridge assigns the right species", instances[0].species.id == "slime")
	_check("bridge assigns the right side", instances[0].side == "side_a")
	var learned_ids: Array[String] = []
	for skill in instances[0].learned_skills:
		learned_ids.append(skill.id)
	_check("bridge's learned_skills matches equipped_skill_ids", learned_ids == ["attack", "frizz"])

func _new_controller(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase, team_a: SavedTeam = null, team_b: SavedTeam = null) -> BattleController:
	if team_a == null:
		team_a = _make_team("Side A Test", [["slime", ["attack"]]])
	if team_b == null:
		team_b = _make_team("Side B Test", [["golem", ["attack"]]])
	var instances_a := TeamToBattleBridge.build_team(team_a, "side_a", monster_db, skill_db, trait_db, 0)
	var instances_b := TeamToBattleBridge.build_team(team_b, "side_b", monster_db, skill_db, trait_db, 100)
	return BattleController.new(instances_a, instances_b, skill_db.skills_by_id)

func _check_controller_gating(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var controller := _new_controller(monster_db, skill_db, trait_db)
	# A lambda captures local variables by value -- mutating a captured Array
	# (appending) is visible outside; reassigning a captured int/String isn't.
	var resolved_events: Array = []
	var probe := func(events: Array) -> void: resolved_events.append(events)
	controller.turn_resolved.connect(probe)

	var side_b_actor := controller.get_state().get_monster_at("side_b", 0)
	controller.submit_fight("side_a", 0, "attack", side_b_actor.instance_id)
	_check("side_a submitting alone doesn't resolve the turn", resolved_events.is_empty())
	_check("side_a slot 0 is marked submitted", controller.is_slot_submitted("side_a", 0))
	_check("side_a is ready (its only pending slot submitted)", controller.is_side_ready("side_a"))
	_check("side_b is not yet ready", not controller.is_side_ready("side_b"))

	var side_a_actor := controller.get_state().get_monster_at("side_a", 0)
	controller.submit_fight("side_b", 0, "attack", side_a_actor.instance_id)
	_check("both sides submitting resolves exactly one turn", resolved_events.size() == 1)

func _check_explicit_targeting(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var controller := _new_controller(monster_db, skill_db, trait_db)
	var side_b_actor := controller.get_state().get_monster_at("side_b", 0)

	controller.submit_fight("side_a", 0, "attack", side_b_actor.instance_id)
	var provider: ScriptedActionProvider = controller._providers["side_a"]
	var side_a_actor := controller.get_state().get_monster_at("side_a", 0)
	var queued: Array = provider._queues.get(side_a_actor.instance_id, [])
	_check(
		"submit_fight queues the explicitly chosen target",
		not queued.is_empty() and queued[0].target_instance_id == side_b_actor.instance_id
	)

func _check_full_battle(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var controller := _new_controller(monster_db, skill_db, trait_db)
	var winners: Array = []
	var probe := func(winner: String) -> void: winners.append(winner)
	controller.battle_ended.connect(probe)

	var turns := 0
	while not controller.is_over() and turns < 100:
		var a := controller.get_state().get_monster_at("side_a", 0)
		var b := controller.get_state().get_monster_at("side_b", 0)
		controller.submit_fight("side_a", 0, "attack", b.instance_id)
		controller.submit_fight("side_b", 0, "attack", a.instance_id)
		turns += 1

	_check("a full 1v1 battle reaches battle_ended within 100 turns", controller.is_over())
	_check(
		"battle_ended fires with a real winner_side",
		winners.size() == 1 and (winners[0] == "side_a" or winners[0] == "side_b")
	)

func _check_multi_slot(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var team_a := _make_team("Multi A", [["slime", ["attack"]], ["dracky", ["attack"]]])
	var team_b := _make_team("Multi B", [["golem", ["attack"]]])
	var controller := _new_controller(monster_db, skill_db, trait_db, team_a, team_b)

	_check("side_a has 2 pending slots (2-member team)", controller.get_pending_slots("side_a") == [0, 1])
	_check("side_b has 1 pending slot (1-member team)", controller.get_pending_slots("side_b") == [0])

	var b_actor := controller.get_state().get_monster_at("side_b", 0)
	var a_slot0 := controller.get_state().get_monster_at("side_a", 0)
	var a_slot1 := controller.get_state().get_monster_at("side_a", 1)

	controller.submit_fight("side_a", 0, "attack", b_actor.instance_id)
	_check("side_a not ready with only 1 of 2 slots submitted", not controller.is_side_ready("side_a"))

	var resolved_count: Array = []
	var probe := func(_events: Array) -> void: resolved_count.append(true)
	controller.turn_resolved.connect(probe)

	controller.submit_fight("side_a", 1, "attack", b_actor.instance_id)
	_check("side_a ready once both its slots submit", controller.is_side_ready("side_a"))
	_check("turn hasn't resolved yet (side_b still pending)", resolved_count.is_empty())

	controller.submit_fight("side_b", 0, "attack", a_slot0.instance_id)
	_check("turn resolves once every pending slot on both sides has submitted", resolved_count.size() == 1)

func _check_orders_swap(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	# 5 members: slots 0-3 go active immediately (ACTIVE_SLOT_COUNT=4), the
	# 5th sits on the bench -- exactly the case Orders/swap needs to exercise.
	var team_a := _make_team("Bench Test", [
		["slime", ["attack"]], ["dracky", ["attack"]], ["golem", ["attack"]],
		["healslime", ["attack"]], ["slime", ["attack"]],
	])
	var team_b := _make_team("Bench Opponent", [["golem", ["attack"]]])
	var controller := _new_controller(monster_db, skill_db, trait_db, team_a, team_b)

	var bench := controller.get_living_bench("side_a")
	_check("5th team member starts on the bench", bench.size() == 1)
	var bench_id: int = bench[0].instance_id

	controller.submit_swap("side_a", 0, bench_id)
	_check("slot 0 is submitted after a swap", controller.is_slot_submitted("side_a", 0))

	var new_slot0 := controller.get_state().get_monster_at("side_a", 0)
	_check("the bench monster now occupies slot 0", new_slot0.instance_id == bench_id)

	var provider: ScriptedActionProvider = controller._providers["side_a"]
	var queued: Array = provider._queues.get(bench_id, [])
	_check("a swap queues no action for the incoming monster this round", queued.is_empty())

func _check_size_aware_packing(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	# aamon=2 slots, aquarion=3 slots, asura_zoma=4 slots (real fixtures).
	# Team: [2-slot, 1-slot, 1-slot] should pack as slots [0,1]=aamon,
	# [2]=slime, [3]=dracky -- exactly filling the 4-slot budget.
	var team_a := _make_team("Packing A", [
		["aamon", ["attack"]], ["slime", ["attack"]], ["dracky", ["attack"]],
	])
	var team_b := _make_team("Packing B", [["golem", ["attack"]]])
	var controller_a := _new_controller(monster_db, skill_db, trait_db, team_a, team_b)
	var state_a := controller_a.get_state()

	var aamon := state_a.side_a_team[0]
	_check("2-slot monster occupies 2 active-slot indices", state_a.get_slots_for_team_index("side_a", 0) == [0, 1])
	_check("get_monster_at returns the same instance for both its slots", state_a.get_monster_at("side_a", 0) == aamon and state_a.get_monster_at("side_a", 1) == aamon)
	_check("the 1-slot monster after it packs into slot 2", state_a.get_monster_at("side_a", 2).species.id == "slime")
	_check("the next 1-slot monster packs into slot 3", state_a.get_monster_at("side_a", 3).species.id == "dracky")
	_check("side_a's pending slots reflect the packed layout (4 filled)", controller_a.get_pending_slots("side_a") == [0, 1, 2, 3])

	# A 4-slot monster occupies the whole roster alone; nothing else fits.
	var team_c := _make_team("Packing C", [["asura_zoma", ["attack"]], ["slime", ["attack"]]])
	var controller_c := _new_controller(monster_db, skill_db, trait_db, team_c, team_b)
	var state_c := controller_c.get_state()
	_check("4-slot monster occupies all 4 active slots alone", state_c.get_slots_for_team_index("side_a", 0) == [0, 1, 2, 3])
	_check("nothing else can be active alongside a 4-slot monster", controller_c.get_living_bench("side_a").size() == 1)

	# [2-slot, 2-slot too big to fit remaining 2? fits exactly, then 1-slot
	# doesn't fit at all] -- a monster that doesn't fit is skipped, and a
	# smaller *later* team member still gets a chance at the remaining room.
	var team_d := _make_team("Packing D", [
		["aquarion", ["attack"]], ["asura_zoma", ["attack"]], ["slime", ["attack"]],
	])
	var controller_d := _new_controller(monster_db, skill_db, trait_db, team_d, team_b)
	var state_d := controller_d.get_state()
	_check("3-slot monster fills slots 0-2", state_d.get_slots_for_team_index("side_a", 0) == [0, 1, 2])
	_check("4-slot monster doesn't fit the remaining 1 slot and is skipped", state_d.get_monster_at("side_a", 3) != state_d.side_a_team[1])
	_check("a smaller later team member fills the remaining slot instead", state_d.get_monster_at("side_a", 3).species.id == "slime")

	# Fainting a 2-slot monster backfills both its vacated slots -- needs two
	# 1-slot bench reserves (healslime, golem) since the initial send-out
	# already filled all 4 active slots with aamon(2)+slime(1)+dracky(1),
	# leaving both extra members on the bench from the start.
	var team_e := _make_team("Packing E", [
		["aamon", ["attack"]], ["slime", ["attack"]], ["dracky", ["attack"]],
		["healslime", ["attack"]], ["golem", ["attack"]],
	])
	var controller_e := _new_controller(monster_db, skill_db, trait_db, team_e, team_b)
	var state_e := controller_e.get_state()
	_check("2 bench reserves available before any faint", controller_e.get_living_bench("side_a").size() == 2)
	var aamon_e := state_e.side_a_team[0]
	aamon_e.current_hp = 0
	FaintHandler.handle_if_fainted(BattleContext.new(state_e), aamon_e)
	_check(
		"fainting a 2-slot monster backfills both vacated slots with living bench members",
		state_e.get_monster_at("side_a", 0) != null and state_e.get_monster_at("side_a", 1) != null
		and state_e.get_monster_at("side_a", 0).species.id != "aamon"
		and state_e.get_monster_at("side_a", 1).species.id != "aamon"
	)

func _check_side_view_rendering(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var team_a := _make_team("View Test A", [["slime", ["attack", "frizz"]]])
	var team_b := _make_team("View Test B", [["golem", ["attack"]]])
	var instances_a := TeamToBattleBridge.build_team(team_a, "side_a", monster_db, skill_db, trait_db, 0)
	var instances_b := TeamToBattleBridge.build_team(team_b, "side_b", monster_db, skill_db, trait_db, 100)
	var controller := BattleController.new(instances_a, instances_b, skill_db.skills_by_id)

	var view: BattleSideView = SideViewScene.instantiate()
	_tree.root.add_child(view)
	await _tree.process_frame
	view.setup(controller, "side_a", skill_db)

	_check("side view starts commanding position 1 (slot 0)", view._current_slot == 0)

	view._on_fight_pressed()
	# _actions_box also always contains the persistent "< Back" button.
	_check("side view renders one button per learned skill", view._actions_box.get_child_count() == 3)

	# "attack" costs 0 MP (always affordable); "frizz" costs 2 MP -- draining
	# MP should disable frizz's button specifically, not attack's.
	instances_a[0].current_mp = 0
	view._rebuild_skill_buttons()
	var attack_disabled := false
	var frizz_disabled := false
	for child in view._actions_box.get_children():
		if child is Button:
			var button := child as Button
			if button.text.begins_with("Attack"):
				attack_disabled = button.disabled
			elif button.text.begins_with("Frizz"):
				frizz_disabled = button.disabled
	_check("side view keeps a 0-MP skill's button enabled", not attack_disabled)
	_check("side view disables a skill button the actor can't afford", frizz_disabled)

	view.queue_free()

func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		print("FAIL: %s" % label)
		_all_passed = false
