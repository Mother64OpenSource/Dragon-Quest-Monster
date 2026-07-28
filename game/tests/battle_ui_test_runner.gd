class_name BattleUiTestRunner
extends RefCounted

## Milestone 5 (multi-slot grid battles) checks: the SavedTeam -> MonsterInstance
## bridge, BattleController's per-slot submit/resolve gating, explicit targeting,
## the swap-in command (submit_swap -- now triggered by dragging a card between
## Main Party and Second Party, not a separate "Orders" menu), a full battle
## running to completion, and BattleSideView rendering the right action
## buttons. Real Window/OS popup behavior, actually dragging a card, and
## clicking through the grid/target-pick flow can't be exercised headlessly
## (see the M5 plan) -- that part is manual-only, verified via F5.

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
	_check_size_aware_swap(monster_db, skill_db, trait_db)
	_check_size_aware_packing(monster_db, skill_db, trait_db)
	_check_multi_slot_acts_once_per_turn(monster_db, skill_db, trait_db)
	_check_turn_resolved_ordering(monster_db, skill_db, trait_db)
	_check_forfeit(monster_db, skill_db, trait_db)
	await _check_side_view_rendering(monster_db, skill_db, trait_db)
	await _check_party_grid_and_drag(monster_db, skill_db, trait_db)
	await _check_party_grid_click_to_select(monster_db, skill_db, trait_db)
	await _check_forfeit_button(monster_db, skill_db, trait_db)
	await _check_arena_rendering(monster_db, skill_db, trait_db)
	await _check_bounce_and_audio(monster_db, skill_db, trait_db)
	await _check_attacks_animate_sequentially(monster_db, skill_db, trait_db)
	await _check_status_icon_on_card(monster_db, skill_db, trait_db)
	await _check_floating_text(monster_db, skill_db, trait_db)
	await _check_defend_button(monster_db, skill_db, trait_db)
	await _check_damage_and_status_numbers(monster_db, skill_db, trait_db)

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

## Regression test for a real bug: BattleController used to emit
## turn_resolved *before* resetting its per-slot "submitted" bookkeeping for
## the new round, so a BattleSideView's handler (which calls
## _advance_to_next_pending_slot() synchronously off that signal) saw the
## just-finished round's stale "everything already submitted" state and
## could never find an unsubmitted slot again -- both windows would get
## stuck forever on "Waiting for the other side...". Checked from inside
## the signal handler itself, matching exactly what the view's handler sees.
func _check_turn_resolved_ordering(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var controller := _new_controller(monster_db, skill_db, trait_db)
	var seen_fresh: Array = []
	var probe := func(_events: Array) -> void:
		seen_fresh.append(not controller.is_slot_submitted("side_a", 0))
	controller.turn_resolved.connect(probe)

	var a := controller.get_state().get_monster_at("side_a", 0)
	var b := controller.get_state().get_monster_at("side_b", 0)
	controller.submit_fight("side_a", 0, "attack", b.instance_id)
	controller.submit_fight("side_b", 0, "attack", a.instance_id)

	_check(
		"turn_resolved fires only after the new round's slots are reset (no stuck 'waiting forever')",
		seen_fresh.size() == 1 and seen_fresh[0] == true
	)

func _check_forfeit(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var controller := _new_controller(monster_db, skill_db, trait_db)

	var submitted_calls: Array = []
	controller.action_submitted.connect(func(side, slot, kind, payload): submitted_calls.append([side, slot, kind, payload]))
	var winners: Array = []
	controller.battle_ended.connect(func(winner_side): winners.append(winner_side))

	controller.forfeit("side_a")
	_check("forfeiting ends the battle immediately", controller.is_over())
	_check("the other side is credited with the win", controller.get_state().winner_side == "side_b")
	_check("battle_ended fires with the correct winner", winners.size() == 1 and winners[0] == "side_b")
	_check(
		"forfeiting emits action_submitted (side_a, forfeit) so online play can forward it for free",
		submitted_calls.size() == 1 and submitted_calls[0] == ["side_a", -1, "forfeit", {}]
	)

	# Forfeiting an already-finished battle is a harmless no-op -- doesn't
	# flip the winner or fire battle_ended a second time.
	controller.forfeit("side_b")
	_check("forfeiting after the battle already ended changes nothing", controller.get_state().winner_side == "side_b" and winners.size() == 1)

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
	# 5th sits on the bench -- exactly the case submit_swap needs to exercise.
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

## The actual reported bug: swapping in a MULTI-slot bench monster used to
## only ever write the single raw index it was dropped on, silently
## overlapping whichever other monster(s) already occupied the rest of its
## footprint -- letting more slot-points than ACTIVE_SLOT_COUNT effectively
## sit active at once. submit_swap() now displaces every monster in the
## incoming monster's way, whole-footprint, rather than just the one at
## the target index.
func _check_size_aware_swap(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	# 4 one-slot monsters active (slots 0-3) + a 2-slot bench reserve
	# (aamon). Swapping aamon in at slot 0 must displace BOTH the 1-slot
	# monster at slot 0 and the separate 1-slot monster at slot 1 -- not
	# just slot 0 -- since aamon needs both indices.
	var team_a := _make_team("Size Aware Swap", [
		["slime", ["attack"]], ["dracky", ["attack"]], ["golem", ["attack"]],
		["healslime", ["attack"]], ["aamon", ["attack"]],
	])
	var team_b := _make_team("Size Aware Swap Opponent", [["golem", ["attack"]]])
	var controller := _new_controller(monster_db, skill_db, trait_db, team_a, team_b)
	var state := controller.get_state()

	var slot0_before := state.get_monster_at("side_a", 0)
	var slot1_before := state.get_monster_at("side_a", 1)
	var bench := controller.get_living_bench("side_a")
	_check("aamon (2-slot) starts on the bench", bench.size() == 1 and bench[0].species.id == "aamon")
	var aamon_id: int = bench[0].instance_id

	# A swap that genuinely can't fit within ACTIVE_SLOT_COUNT starting at
	# the target slot is rejected outright (checked before the real swap
	# below, while aamon is still a valid bench candidate to attempt with).
	var before_slot3 := state.get_monster_at("side_a", 3)
	controller.submit_swap("side_a", 3, aamon_id)  # slot 3 + 2 slots = 5 > ACTIVE_SLOT_COUNT
	_check(
		"a swap that would exceed ACTIVE_SLOT_COUNT is rejected, not partially applied",
		state.get_monster_at("side_a", 3) == before_slot3 and not controller.is_slot_submitted("side_a", 3)
	)

	controller.submit_swap("side_a", 0, aamon_id)

	_check("aamon now occupies slot 0", state.get_monster_at("side_a", 0).instance_id == aamon_id)
	_check(
		"aamon also claims slot 1, not just the slot it was dropped on",
		state.get_monster_at("side_a", 1).instance_id == aamon_id
	)
	_check("no monster is duplicated across slots 0 and 1", state.get_monster_at("side_a", 0) == state.get_monster_at("side_a", 1))

	var new_bench := controller.get_living_bench("side_a")
	var new_bench_ids: Array[int] = []
	for m in new_bench:
		new_bench_ids.append(m.instance_id)
	_check(
		"both displaced monsters (originally at slots 0 and 1) end up on the bench",
		new_bench_ids.has(slot0_before.instance_id) and new_bench_ids.has(slot1_before.instance_id)
	)
	_check("a displaced monster's slot resets to -1", slot0_before.slot == -1 and slot1_before.slot == -1)

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
	# Pending slots are deduped per acting monster, not per raw slot index --
	# aamon spans slots 0 and 1 but is one actor and should only appear once
	# (regression test for a real bug: it used to get asked to command twice
	# per round, overwriting its own queued action and needlessly double
	# ticking end-of-turn status effects).
	_check("side_a's pending slots are deduped per monster, not per raw slot (aamon once, at its first slot)", controller_a.get_pending_slots("side_a") == [0, 2, 3])

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

## Regression test for a real bug: a multi-slot monster spans more than one
## raw slot index, but TurnManager and BattleController's pending-slot
## bookkeeping used to treat each raw slot it occupied as independently
## actionable -- the player got asked to command it once per slot, and (since
## submitting an action always overwrites, never appends, that instance_id's
## queue) whichever action was submitted last silently replaced the first.
## Confirms end-to-end, via the actual turn resolution, that a 2-slot
## monster produces exactly one SkillUsedEvent per turn.
func _check_multi_slot_acts_once_per_turn(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var team_a := _make_team("SingleAction A", [
		["aamon", ["attack"]], ["slime", ["attack"]], ["dracky", ["attack"]],
	])
	var team_b := _make_team("SingleAction B", [["golem", ["attack"]]])
	var controller := _new_controller(monster_db, skill_db, trait_db, team_a, team_b)
	var state := controller.get_state()

	var aamon := state.side_a_team[0]
	var b_actor := state.get_monster_at("side_b", 0)

	var events: Array = []
	var probe := func(turn_events: Array) -> void: events.append_array(turn_events)
	controller.turn_resolved.connect(probe)

	for slot in controller.get_pending_slots("side_a"):
		controller.submit_fight("side_a", slot, "attack", b_actor.instance_id)
	controller.submit_fight("side_b", 0, "attack", aamon.instance_id)

	var aamon_actions := 0
	for event in events:
		if event is SkillUsedEvent and event.actor_instance_id == aamon.instance_id:
			aamon_actions += 1
	_check("a 2-slot monster's action fires exactly once per turn, not once per slot it occupies", aamon_actions == 1)

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
	var attack_tooltip := ""
	var frizz_tooltip := ""
	for child in view._actions_box.get_children():
		if child is Button:
			var button := child as Button
			if button.text.begins_with("Attack"):
				attack_disabled = button.disabled
				attack_tooltip = button.tooltip_text
			elif button.text.begins_with("Frizz"):
				frizz_disabled = button.disabled
				frizz_tooltip = button.tooltip_text
	_check("side view keeps a 0-MP skill's button enabled", not attack_disabled)
	_check("side view disables a skill button the actor can't afford", frizz_disabled)
	_check("attack button's tooltip shows its move description", attack_tooltip == skill_db.get_skill("attack").description)
	_check("frizz button's tooltip shows its move description", frizz_tooltip == skill_db.get_skill("frizz").description)

	# The battle log should actually narrate what happened, not just track
	# HP bars silently -- resolve one real turn and check the log text names
	# the turn, the move used, and the resulting damage.
	instances_a[0].current_mp = instances_a[0].species.base_mp
	controller.submit_fight("side_a", 0, "attack", instances_b[0].instance_id)
	controller.submit_fight("side_b", 0, "attack", instances_a[0].instance_id)
	# Attacks now animate one at a time (see wiki/log.md) instead of the log
	# filling in all at once -- give both this round's attacks time to
	# finish their sequential animations before reading the final log text.
	await _tree.create_timer(2 * (BattleArena3D.LUNGE_OUT_TIME + BattleArena3D.LUNGE_BACK_TIME) + 0.3).timeout
	var log_text := view._log_label.text
	_check("battle log names the round", log_text.contains("Round 1"))
	_check("battle log narrates the opening send-out", log_text.contains("enters the battle!"))
	_check("battle log narrates the move used", log_text.contains("used Attack!"))
	_check("battle log narrates the resulting damage", log_text.contains("damage!"))

	view.queue_free()

## Main Party (active)/Second Party (bench) rows replaced the old single
## "Your Party" grid + separate "Orders" menu. Real drag-and-drop can't be
## exercised headlessly (same M3-era limitation as the team builder's own
## drag-to-reorder), so _on_party_card_dropped() is called directly here --
## exactly the handler a real drop would call.
##
## Dropping now STAGES a proposed formation change rather than calling
## submit_swap() immediately -- the user-reported problem this fixes: the
## old immediate-commit version locked a slot's swap in the instant you
## dropped (submit_swap() marks that slot "submitted" for the round), so
## you could only ever pick ONE replacement per slot with no way to
## compare a couple of combinations first. Nothing should touch the
## engine until _on_apply_formation_pressed() runs.
func _check_party_grid_and_drag(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	# Two bench reserves (aamon, a 2nd slime) rather than one -- lets the
	# "changed my mind" step below pick between two genuinely-benched
	# options for the same slot, without ever touching an already-active
	# monster (a separate, deliberately distinct case -- see the last part
	# of this check).
	var team_a := _make_team("Party Grid A", [
		["slime", ["attack"]], ["dracky", ["attack"]], ["golem", ["attack"]],
		["healslime", ["attack"]], ["aamon", ["attack"]], ["slime", ["attack"]],
	])
	var team_b := _make_team("Party Grid B", [["golem", ["attack"]]])
	var instances_a := TeamToBattleBridge.build_team(team_a, "side_a", monster_db, skill_db, trait_db, 0)
	var instances_b := TeamToBattleBridge.build_team(team_b, "side_b", monster_db, skill_db, trait_db, 100)
	var controller := BattleController.new(instances_a, instances_b, skill_db.skills_by_id)

	var view: BattleSideView = SideViewScene.instantiate()
	_tree.root.add_child(view)
	await _tree.process_frame
	view.setup(controller, "side_a", skill_db)

	_check("Main Party shows the 4 active monsters", _count_cards(view._main_party_row) == 4)
	_check("Second Party shows the 2 bench monsters", _count_cards(view._second_party_row) == 2)
	_check("Apply Formation starts disabled -- nothing staged yet", view._apply_formation_button.disabled)

	var slime_id := instances_a[0].instance_id    # active, slot 0
	var dracky_id := instances_a[1].instance_id   # active, slot 1
	var aamon_id := instances_a[4].instance_id    # bench, 2-slot
	var slime2_id := instances_a[5].instance_id   # bench, 1-slot -- the "second choice"

	# Dropping bench-onto-bench is a no-op -- nothing to swap either
	# direction, and nothing should be staged.
	view._on_party_card_dropped(aamon_id, -1, slime2_id)
	_check("dropping a bench card onto another bench-side target stages nothing", not view._has_staged_changes(controller.get_state()))

	# Staging aamon (2-slot) into slot 0 must be a pure UI edit -- the
	# engine's real active formation is untouched until Apply.
	view._on_party_card_dropped(aamon_id, 0, -1)
	_check("staging a drop doesn't touch the engine yet", controller.get_state().get_monster_at("side_a", 0).instance_id == slime_id)
	_check("the Apply button enables once something is staged", not view._apply_formation_button.disabled)
	_check("aamon is staged into slot 0", view._staged_active_ids[0] == aamon_id)
	_check(
		"aamon's own 2-slot footprint also displaces the separate monster staged at slot 1",
		view._staged_active_ids[1] == aamon_id and not view._staged_active_ids.has(dracky_id)
	)

	# The actual reported problem: changing your mind about slot 0 before
	# applying must still be possible -- staging a DIFFERENT bench monster
	# there should simply replace the previous staged choice, not be
	# blocked the way a second submit_swap() on an already-submitted slot
	# would be. slime2 is a genuine bench reserve throughout (never really
	# active), so this is an unambiguous bench-for-bench swap of the
	# staged choice.
	view._on_party_card_dropped(slime2_id, 0, -1)
	_check(
		"staging a different combination for the same slot before Apply works -- not locked to the first choice",
		view._staged_active_ids[0] == slime2_id
	)
	_check(
		"aamon's now-unneeded second slot frees up rather than staying claimed",
		view._staged_active_ids[1] != aamon_id
	)
	_check("the engine still hasn't changed at all", controller.get_state().get_monster_at("side_a", 0).instance_id == slime_id)

	# Applying commits the final staged arrangement in one go.
	view._on_apply_formation_pressed()
	var state := controller.get_state()
	_check("Apply commits the final staged choice to the engine", state.get_monster_at("side_a", 0).instance_id == slime2_id)
	var slime_now_benched := false
	var aamon_still_benched := false
	for m in controller.get_living_bench("side_a"):
		if m.instance_id == slime_id:
			slime_now_benched = true
		if m.instance_id == aamon_id:
			aamon_still_benched = true
	_check("the displaced original slot-0 monster ends up on the bench after Apply", slime_now_benched)
	_check("aamon (never actually applied, only briefly staged) is still just on the bench", aamon_still_benched)
	_check("Apply Formation disables again once nothing is staged", view._apply_formation_button.disabled)

	# Defense in depth: _on_party_card_dropped() itself already refuses to
	# drag an already-staged-active card onto another active slot (it's a
	# no-op through the normal UI path, so this exact scenario can't arise
	# from real dragging) -- but _on_apply_formation_pressed() has its own
	# independent guard against it too, since submit_swap() has no notion
	# of "relocate an already-active monster" (it would duplicate that
	# monster across two slots instead of moving it). Exercise that guard
	# directly via _stage_drop_at_slot() (bypassing the drop handler's own
	# guard on purpose) to prove Apply is safe even if something else ever
	# manages to stage this. Dracky is still genuinely active at slot 1
	# throughout all of the above -- never benched.
	var dracky_instance := controller.get_state().get_monster_by_instance_id(dracky_id)
	view._stage_drop_at_slot(dracky_instance, 2)
	_check("the staged array can (in principle) propose repositioning an already-active monster", view._staged_active_ids[2] == dracky_id)
	view._on_apply_formation_pressed()
	var final_state := controller.get_state()
	var dracky_slots := 0
	for slot in range(BattleController.ACTIVE_SLOT_COUNT):
		var occupant := final_state.get_monster_at("side_a", slot)
		if occupant != null and occupant.instance_id == dracky_id:
			dracky_slots += 1
	_check("applying such a plan never duplicates a monster across two slots", dracky_slots == 1)

	view.queue_free()

## Real-world reported bug: two active monsters at 0 HP that auto-backfill
## never replaced (no reserve fit -- see faint_handler.gd), a THIRD active
## monster still alive and pending, and a healthy bench reserve -- the
## player dragged the bench card onto a fainted active slot and nothing
## happened. Confirmed (see wiki/log.md) the actual root cause was the
## drag gesture itself never reaching the engine's drop handler, not a
## _can_edit_formation() gating bug -- _recompute_pending_slots() already
## correctly excludes a fainted occupant's slot from "needs a command,"
## which is why a still-living slot (golem here) keeps _current_slot valid
## and _can_edit_formation() true throughout. This exercises the click-to-
## select fallback (_on_party_card_clicked()) that fixes it, calling it
## directly rather than simulating a real click -- consistent with how
## _check_party_grid_and_drag above calls _on_party_card_dropped()
## directly rather than simulating a real drag.
func _check_party_grid_click_to_select(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var team_a := _make_team("Click Select A", [
		["slime", ["attack"]], ["dracky", ["attack"]], ["golem", ["attack"]],
		["healslime", ["attack"]], ["aamon", ["attack"]],
	])
	var team_b := _make_team("Click Select B", [["golem", ["attack"]]])
	var instances_a := TeamToBattleBridge.build_team(team_a, "side_a", monster_db, skill_db, trait_db, 0)
	var instances_b := TeamToBattleBridge.build_team(team_b, "side_b", monster_db, skill_db, trait_db, 100)
	var controller := BattleController.new(instances_a, instances_b, skill_db.skills_by_id)

	var view: BattleSideView = SideViewScene.instantiate()
	_tree.root.add_child(view)
	await _tree.process_frame
	view.setup(controller, "side_a", skill_db)

	var slime_id := instances_a[0].instance_id    # active slot 0 -- about to "faint"
	var dracky_id := instances_a[1].instance_id   # active slot 1 -- about to "faint"
	var golem_id := instances_a[2].instance_id    # active slot 2 -- stays alive and pending
	var aamon_id := instances_a[4].instance_id    # bench, alive

	# Directly zero HP rather than running real damage -- is_fainted() is
	# purely current_hp <= 0 (see monster_instance.gd), and no reserve
	# backfill is expected to have run here (this is testing the UI's
	# reaction to a fainted-but-still-occupied slot, not FaintHandler's own
	# backfill-or-not decision, which is covered elsewhere).
	instances_a[0].current_hp = 0
	instances_a[1].current_hp = 0
	controller._recompute_pending_slots()
	view._advance_to_next_pending_slot()
	view._refresh()

	_check("a fainted active occupant is correctly excluded from pending, not '???'", view._current_slot != -1)
	_check("with a living slot still pending, formation editing stays enabled", view._can_edit_formation())

	# The exact reported gesture, done via two clicks instead of a drag:
	# click the healthy bench card first...
	view._on_party_card_clicked(aamon_id, -1, aamon_id)
	_check("the first click picks the bench monster up", view._selected_party_instance_id == aamon_id)
	_check("nothing is staged yet from a pick-up alone", not view._has_staged_changes(controller.get_state()))

	# ...then click the fainted main-party slot to drop it there.
	view._on_party_card_clicked(slime_id, 0, -1)
	_check("the pick-up is cleared once a drop completes", view._selected_party_instance_id == -1)
	_check("aamon is now staged into the fainted slot", view._staged_active_ids[0] == aamon_id)
	_check("Apply Formation enables from a click-driven stage, same as a drag would", not view._apply_formation_button.disabled)
	_check("the engine's real formation is still untouched before Apply", controller.get_state().get_monster_at("side_a", 0).instance_id == slime_id)

	# Clicking a card a second time (with nothing else selected) picks it
	# up, then clicking it again cancels rather than dropping it onto
	# itself. golem (alive, untouched by anything above) stands in here --
	# dracky is fainted in this exact scenario and correctly can't be
	# picked up at all (see the rejection branch of
	# _on_party_card_clicked()).
	view._on_party_card_clicked(golem_id, 2, -1)
	_check("clicking a fresh, alive card with nothing else selected picks it up", view._selected_party_instance_id == golem_id)
	view._on_party_card_clicked(golem_id, 2, -1)
	_check("clicking the very same card again cancels the pick-up", view._selected_party_instance_id == -1)

	# Applying commits the click-staged plan just like a dragged one would.
	view._on_apply_formation_pressed()
	var state := controller.get_state()
	_check("Apply commits the click-staged swap to the real engine formation", state.get_monster_at("side_a", 0).instance_id == aamon_id)
	var slime_now_benched := false
	for m in controller.get_living_bench("side_a"):
		if m.instance_id == slime_id:
			slime_now_benched = true
	# slime fainted with 0 HP but was never actually removed from the team
	# roster -- get_living_bench() filters out fainted monsters by design
	# (see battle_controller.gd), so it correctly does NOT show up there;
	# what matters is that it no longer occupies an active slot.
	var slime_still_active := false
	for slot in range(BattleController.ACTIVE_SLOT_COUNT):
		var occupant := state.get_monster_at("side_a", slot)
		if occupant != null and occupant.instance_id == slime_id:
			slime_still_active = true
	_check("the fainted monster that got swapped out no longer occupies any active slot", not slime_still_active)
	_check("(sanity) get_living_bench correctly excludes a fainted monster regardless of slot", not slime_now_benched)
	_check(
		"golem (never touched by any of the clicks above) is still the one commanding",
		state.get_monster_at("side_a", view._current_slot).instance_id == golem_id
	)

	view.queue_free()

func _count_cards(container: Container) -> int:
	return container.get_child_count()

func _check_forfeit_button(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var team_a := _make_team("Forfeit UI A", [["slime", ["attack"]]])
	var team_b := _make_team("Forfeit UI B", [["golem", ["attack"]]])
	var instances_a := TeamToBattleBridge.build_team(team_a, "side_a", monster_db, skill_db, trait_db, 0)
	var instances_b := TeamToBattleBridge.build_team(team_b, "side_b", monster_db, skill_db, trait_db, 100)
	var controller := BattleController.new(instances_a, instances_b, skill_db.skills_by_id)

	var view: BattleSideView = SideViewScene.instantiate()
	_tree.root.add_child(view)
	await _tree.process_frame
	view.setup(controller, "side_a", skill_db)

	_check("the forfeit button is visible on the main command screen", view._forfeit_button.visible)

	# Forfeit is a top-level choice alongside Fight/Tactics, not something
	# offered inside their sub-menus -- opening Fight's skill list should
	# hide it, and backing out should bring it back.
	view._on_fight_pressed()
	_check("the forfeit button is hidden while browsing the Fight menu", not view._forfeit_button.visible)
	view._on_actions_back_pressed()
	_check("the forfeit button reappears after backing out of the Fight menu", view._forfeit_button.visible)

	view._on_forfeit_pressed()
	_check("pressing forfeit opens the confirmation dialog rather than ending the battle right away", view._forfeit_confirm_dialog.visible and not controller.is_over())

	view._on_forfeit_confirmed()
	_check("confirming forfeit ends the battle crediting the opponent", controller.is_over() and controller.get_state().winner_side == "side_b")
	_check("the view shows the loss from the forfeiting side's own perspective", view._result_panel.visible and view._result_label.text == "You Lose!")

	view._render_command_panel()
	_check("the forfeit button hides once the battle is over", not view._forfeit_button.visible)

	view.queue_free()

## Milestone 10: the 3D arena (BattleArena3D) that renders both sides'
## monsters as billboarded sprites, plus the always-visible turn counter.
## None of this needs real rendering to verify -- sprite existence,
## position/scale math, and node identity/lifecycle are all pure data,
## checkable the same way the rest of this project's headless suites
## already prove non-visual properties of things that are normally seen.
func _check_arena_rendering(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var team_a := _make_team("Arena A", [["aamon", ["attack"]]])
	var team_b := _make_team("Arena B", [["golem", ["attack"]]])
	var instances_a := TeamToBattleBridge.build_team(team_a, "side_a", monster_db, skill_db, trait_db, 0)
	var instances_b := TeamToBattleBridge.build_team(team_b, "side_b", monster_db, skill_db, trait_db, 100)
	var controller := BattleController.new(instances_a, instances_b, skill_db.skills_by_id)

	var view: BattleSideView = SideViewScene.instantiate()
	_tree.root.add_child(view)
	await _tree.process_frame
	view.setup(controller, "side_a", skill_db)

	var aamon_id := instances_a[0].instance_id
	var golem_id := instances_b[0].instance_id

	_check("arena has a sprite for the 2-slot monster", view._arena.get_sprite(aamon_id) != null)
	_check("arena has a sprite for the opponent", view._arena.get_sprite(golem_id) != null)

	var aamon_sprite := view._arena.get_sprite(aamon_id)
	var aamon_texture_height := aamon_sprite.texture.get_height() if aamon_sprite.texture != null else 0
	_check(
		"a 2-slot monster's sprite height is normalized from its own texture's real height, not a flat scale",
		aamon_texture_height > 0 and is_equal_approx(aamon_sprite.pixel_size, BattleArena3D.SLOT_TARGET_HEIGHT[2] / float(aamon_texture_height))
	)

	var expected_xz: Vector3 = (view._arena._my_anchors[0].global_position + view._arena._my_anchors[1].global_position) / 2.0
	var aamon_rendered_height: float = aamon_sprite.pixel_size * aamon_texture_height
	var expected_pos := Vector3(expected_xz.x, BattleArena3D.TILE_GROUND_Y + aamon_rendered_height / 2.0, expected_xz.z)
	_check(
		"a 2-slot monster's sprite sits at the anchors' XZ midpoint, standing on the ground rather than floating at the anchors' own Y",
		aamon_sprite.global_position.is_equal_approx(expected_pos)
	)

	var sprite_again := view._arena.get_sprite(aamon_id)
	_check("re-syncing reuses the same sprite instance, not a rebuilt one", aamon_sprite == sprite_again)

	_check("turn counter reads Round 1 before any round resolves", view._turn_counter_label.text == "Round 1")
	controller.submit_fight("side_a", 0, "attack", golem_id)
	controller.submit_fight("side_b", 0, "attack", aamon_id)
	# Attacks animate sequentially now -- give both this round's attacks time
	# to finish before checking the counter that only updates once the whole
	# round's _refresh() finally runs.
	await _tree.create_timer(2 * (BattleArena3D.LUNGE_OUT_TIME + BattleArena3D.LUNGE_BACK_TIME) + 0.3).timeout
	_check("turn counter reads Round 2 once the first round resolves", view._turn_counter_label.text == "Round 2")

	view.queue_free()

	# A 4-slot monster fills the whole roster alone -- scale should follow
	# the same formula at the other end of the range.
	var team_c := _make_team("Arena C", [["asura_zoma", ["attack"]]])
	var instances_c := TeamToBattleBridge.build_team(team_c, "side_a", monster_db, skill_db, trait_db, 0)
	var controller_c := BattleController.new(instances_c, instances_b, skill_db.skills_by_id)
	var view_c: BattleSideView = SideViewScene.instantiate()
	_tree.root.add_child(view_c)
	await _tree.process_frame
	view_c.setup(controller_c, "side_a", skill_db)
	var zoma_sprite := view_c._arena.get_sprite(instances_c[0].instance_id)
	var zoma_texture_height := zoma_sprite.texture.get_height() if zoma_sprite.texture != null else 0
	_check(
		"a 4-slot monster's sprite height is normalized the same way, at the other end of the slot range",
		zoma_texture_height > 0 and is_equal_approx(zoma_sprite.pixel_size, BattleArena3D.SLOT_TARGET_HEIGHT[4] / float(zoma_texture_height))
	)
	view_c.queue_free()

	# The actual bug this normalization fixes: two different 1-slot monsters
	# whose source art differs in native pixel height (some species use a
	# tight pixel-sprite crop, others a much larger fan-art image) must still
	# render at the SAME on-screen height -- not whichever's source image
	# happened to be taller, which is what a single flat pixel_size for
	# everyone used to produce.
	var team_f := _make_team("Arena F", [["slime", ["attack"]], ["dracky", ["attack"]]])
	var instances_f := TeamToBattleBridge.build_team(team_f, "side_a", monster_db, skill_db, trait_db, 0)
	var controller_f := BattleController.new(instances_f, instances_b, skill_db.skills_by_id)
	var view_f: BattleSideView = SideViewScene.instantiate()
	_tree.root.add_child(view_f)
	await _tree.process_frame
	view_f.setup(controller_f, "side_a", skill_db)
	var slime_sprite_f := view_f._arena.get_sprite(instances_f[0].instance_id)
	var dracky_sprite_f := view_f._arena.get_sprite(instances_f[1].instance_id)
	var slime_height := slime_sprite_f.pixel_size * slime_sprite_f.texture.get_height()
	var dracky_height := dracky_sprite_f.pixel_size * dracky_sprite_f.texture.get_height()
	_check(
		"two same-slot monsters render at the same on-screen height regardless of their source art's native size",
		is_equal_approx(slime_height, dracky_height)
	)
	view_f.queue_free()

	# A fainted monster's sprite stays around (so a backfill mid-flight
	# doesn't pop it away instantly) but should actually disappear from
	# view -- alpha 0, not just a dim tint -- since a monster that faints
	# and has no living reserve left to backfill its slot keeps getting
	# re-synced every refresh; if FAINTED_MODULATE stayed opaque, that
	# resync would undo animate_faint()'s fade-out the moment it ran.
	var team_d := _make_team("Arena D", [["slime", ["attack"]]])
	var instances_d := TeamToBattleBridge.build_team(team_d, "side_a", monster_db, skill_db, trait_db, 0)
	var controller_d := BattleController.new(instances_d, instances_b, skill_db.skills_by_id)
	var view_d: BattleSideView = SideViewScene.instantiate()
	_tree.root.add_child(view_d)
	await _tree.process_frame
	view_d.setup(controller_d, "side_a", skill_db)
	var slime_id := instances_d[0].instance_id
	instances_d[0].current_hp = 0
	FaintHandler.handle_if_fainted(BattleContext.new(controller_d.get_state()), instances_d[0])
	view_d._arena.sync_monsters(controller_d.get_state(), "side_a")
	var slime_sprite := view_d._arena.get_sprite(slime_id)
	_check(
		"a fainted monster's sprite persists but is fully invisible",
		slime_sprite != null and is_equal_approx(slime_sprite.modulate.a, 0.0)
	)

	# animate_faint() itself: fades a still-visible sprite out over time,
	# rather than the sync-driven instant snap to FAINTED_MODULATE above.
	var team_g := _make_team("Arena G", [["slime", ["attack"]]])
	var instances_g := TeamToBattleBridge.build_team(team_g, "side_a", monster_db, skill_db, trait_db, 0)
	var controller_g := BattleController.new(instances_g, instances_b, skill_db.skills_by_id)
	var view_g: BattleSideView = SideViewScene.instantiate()
	_tree.root.add_child(view_g)
	await _tree.process_frame
	view_g.setup(controller_g, "side_a", skill_db)
	var slime_sprite_g := view_g._arena.get_sprite(instances_g[0].instance_id)
	_check("before fainting, the sprite is fully visible", is_equal_approx(slime_sprite_g.modulate.a, 1.0))
	view_g._arena.animate_faint(instances_g[0].instance_id)
	await _tree.process_frame
	_check("mid-fade, the sprite is partway between visible and gone", slime_sprite_g.modulate.a < 1.0)
	await _tree.create_timer(BattleArena3D.FAINT_FADE_TIME + 0.2).timeout
	_check("once the fade finishes, the sprite is fully invisible", is_equal_approx(slime_sprite_g.modulate.a, 0.0))
	view_g.queue_free()
	view_d.queue_free()

	# Once a monster is fully backfilled away (no longer occupying any active
	# slot at all, as opposed to merely fainted-but-still-there), its sprite
	# should actually be freed, not linger forever.
	var team_e := _make_team("Arena E", [
		["aamon", ["attack"]], ["slime", ["attack"]], ["dracky", ["attack"]],
		["healslime", ["attack"]], ["golem", ["attack"]],
	])
	var instances_e := TeamToBattleBridge.build_team(team_e, "side_a", monster_db, skill_db, trait_db, 0)
	var controller_e := BattleController.new(instances_e, instances_b, skill_db.skills_by_id)
	var view_e: BattleSideView = SideViewScene.instantiate()
	_tree.root.add_child(view_e)
	await _tree.process_frame
	view_e.setup(controller_e, "side_a", skill_db)
	var aamon_e_id := instances_e[0].instance_id
	_check("the 2-slot monster has a sprite before fainting", view_e._arena.get_sprite(aamon_e_id) != null)
	instances_e[0].current_hp = 0
	FaintHandler.handle_if_fainted(BattleContext.new(controller_e.get_state()), instances_e[0])
	view_e._arena.sync_monsters(controller_e.get_state(), "side_a")
	_check("a fully backfilled-away monster's sprite is freed", view_e._arena.get_sprite(aamon_e_id) == null)
	view_e.queue_free()

## Milestone 11 (+ the later "attack toward the enemy, not just a bounce"
## revision): the attack Tween and the audio no-op guard. Tweens really do
## run against the SceneTree's frame clock in a headless run, so this can be
## proven by waiting real frames/time rather than needing any pixel rendering.
func _check_bounce_and_audio(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var team_a := _make_team("Bounce A", [["slime", ["attack"]]])
	var team_b := _make_team("Bounce B", [["golem", ["attack"]]])
	var instances_a := TeamToBattleBridge.build_team(team_a, "side_a", monster_db, skill_db, trait_db, 0)
	var instances_b := TeamToBattleBridge.build_team(team_b, "side_b", monster_db, skill_db, trait_db, 100)
	var controller := BattleController.new(instances_a, instances_b, skill_db.skills_by_id)

	var view: BattleSideView = SideViewScene.instantiate()
	_tree.root.add_child(view)
	await _tree.process_frame
	view.setup(controller, "side_a", skill_db)

	var slime_id := instances_a[0].instance_id
	var golem_id := instances_b[0].instance_id
	var sprite := view._arena.get_sprite(slime_id)
	var base_pos := sprite.position

	view._arena.animate_attack(slime_id, golem_id)
	_check("animate_attack doesn't move the sprite synchronously", sprite.position.is_equal_approx(base_pos))

	for i in range(3):
		await _tree.process_frame
	_check("mid-attack, the sprite has moved away from its resting spot", not sprite.position.is_equal_approx(base_pos))

	await _tree.create_timer(BattleArena3D.LUNGE_OUT_TIME + BattleArena3D.LUNGE_BACK_TIME + 0.1).timeout
	_check("once the attack finishes, the sprite is back at its resting spot", sprite.position.is_equal_approx(base_pos))

	# A self-targeted "attack" (actor_id == target_id) has no enemy to step
	# toward -- falls back to a plain bob in place instead.
	view._arena.animate_attack(slime_id, slime_id)
	for i in range(3):
		await _tree.process_frame
	_check("a self-targeted animation bobs in place instead of stepping nowhere", not is_equal_approx(sprite.position.y, base_pos.y))
	await _tree.create_timer(BattleArena3D.BOB_UP_TIME + BattleArena3D.BOB_DOWN_TIME + 0.1).timeout

	# An unknown/already-removed instance id is a harmless no-op.
	view._arena.animate_attack(-999, golem_id)
	_check("animating an unknown instance id doesn't error", true)

	# A rapid re-fire kills the previous tween instead of stacking a second
	# one on top of it.
	view._arena.animate_attack(slime_id, golem_id)
	var first_tween: Tween = view._arena._tweens[slime_id]
	view._arena.animate_attack(slime_id, golem_id)
	var second_tween: Tween = view._arena._tweens[slime_id]
	_check(
		"a rapid re-fire kills the old tween rather than stacking a new one",
		first_tween != second_tween and not first_tween.is_valid()
	)

	# Every real sfx file loads a genuine stream (see battle_audio.gd), except
	# menu_select, which has no matching supplied sound and stays null on
	# purpose -- both a real stream and a deliberately-null one must play
	# without throwing.
	view._audio.play_attack("Spell")
	view._audio.play_attack("Slash")
	view._audio.play_attack("Body")
	view._audio.play_hit(true)
	view._audio.play_hit(false)
	view._audio.play_dodge()
	view._audio.play_miss()
	view._audio.play_faint()
	view._audio.play_stat_changed(1)
	view._audio.play_stat_changed(-1)
	view._audio.play_stat_changed(0)
	view._audio.play_status_applied("poison")
	view._audio.play_status_applied("sleep")
	view._audio.play_status_applied("confusion")
	view._audio.play_guard()
	view._audio.play_heal()
	view._audio.play_enter_battle()
	view._audio.play_forfeit()
	view._audio.play_menu_select()
	_check("every battle sfx call (real stream or null) plays without throwing", true)
	_check(
		"every real sfx file actually loaded a stream instead of silently missing",
		view._audio._weapon_attack_stream != null and view._audio._natural_attack_stream != null
		and view._audio._cast_stream != null and view._audio._hit_stream != null
		and view._audio._critical_hit_stream != null and view._audio._dodge_stream != null
		and view._audio._miss_stream != null and view._audio._faint_stream != null
		and view._audio._buff_stream != null and view._audio._debuff_stream != null
		and view._audio._poison_hit_stream != null and view._audio._sleep_hit_stream != null
		and view._audio._guard_stream != null and view._audio._heal_stream != null
		and view._audio._enter_battle_stream != null and view._audio._forfeit_stream != null
	)
	_check("menu_select has no matching supplied sound and stays null on purpose", view._audio._menu_select_stream == null)

	view.queue_free()

## Attacks in a round with more than one now play out one at a time rather
## than all firing instantly -- if they still fired in parallel, _refresh()
## (and the turn counter it updates) would run almost immediately after both
## sides submit. Checking a beat later, while the sequential animations are
## still in progress, proves that's no longer the case.
func _check_attacks_animate_sequentially(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var team_a := _make_team("Sequence A", [["slime", ["attack"]]])
	var team_b := _make_team("Sequence B", [["golem", ["attack"]]])
	var instances_a := TeamToBattleBridge.build_team(team_a, "side_a", monster_db, skill_db, trait_db, 0)
	var instances_b := TeamToBattleBridge.build_team(team_b, "side_b", monster_db, skill_db, trait_db, 100)
	var controller := BattleController.new(instances_a, instances_b, skill_db.skills_by_id)

	var view: BattleSideView = SideViewScene.instantiate()
	_tree.root.add_child(view)
	await _tree.process_frame
	view.setup(controller, "side_a", skill_db)

	controller.submit_fight("side_a", 0, "attack", instances_b[0].instance_id)
	controller.submit_fight("side_b", 0, "attack", instances_a[0].instance_id)

	await _tree.process_frame
	_check(
		"the round hasn't finished resolving yet while its attacks are still animating one at a time",
		view._turn_counter_label.text == "Round 1"
	)

	var per_attack_duration: float = BattleArena3D.LUNGE_OUT_TIME + BattleArena3D.LUNGE_BACK_TIME
	await _tree.create_timer(per_attack_duration * 2 + 0.3).timeout
	_check(
		"the round has finished once both sequential attacks are done animating",
		view._turn_counter_label.text == "Round 2"
	)

	view.queue_free()

## A monster's card should badge whatever status it's currently afflicted
## with -- a small icon carrying the status's real description as a hover
## tooltip, same tooltip-on-hover pattern already used for moves.
func _check_status_icon_on_card(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var team_a := _make_team("Status Icon A", [["slime", ["attack"]]])
	var team_b := _make_team("Status Icon B", [["golem", ["attack"]]])
	var instances_a := TeamToBattleBridge.build_team(team_a, "side_a", monster_db, skill_db, trait_db, 0)
	var instances_b := TeamToBattleBridge.build_team(team_b, "side_b", monster_db, skill_db, trait_db, 100)
	var controller := BattleController.new(instances_a, instances_b, skill_db.skills_by_id)

	var view: BattleSideView = SideViewScene.instantiate()
	_tree.root.add_child(view)
	await _tree.process_frame
	view.setup(controller, "side_a", skill_db)

	var poison := skill_db.get_status("poison")
	instances_a[0].active_status = StatusInstance.new(poison)
	view._refresh()

	var icon := _find_texture_rect_with_tooltip(view, "Poison:")
	_check("an afflicted monster's card shows a status icon with a real tooltip", icon != null and icon.tooltip_text == "%s: %s" % [poison.display_name, poison.description])
	_check("the status icon actually has a texture assigned", icon != null and icon.texture != null)

	view.queue_free()

## A short callout ("Miss!"/"Critical!") floating above a sprite's own head
## for a missed/dodged/critical hit. Node creation/cleanup and text/color are
## all pure data, checkable the same way _check_arena_rendering() already
## proves other non-pixel properties of the 3D arena without real rendering.
func _check_floating_text(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var team_a := _make_team("Floating Text A", [["slime", ["attack"]]])
	var team_b := _make_team("Floating Text B", [["golem", ["attack"]]])
	var instances_a := TeamToBattleBridge.build_team(team_a, "side_a", monster_db, skill_db, trait_db, 0)
	var instances_b := TeamToBattleBridge.build_team(team_b, "side_b", monster_db, skill_db, trait_db, 100)
	var controller := BattleController.new(instances_a, instances_b, skill_db.skills_by_id)

	var view: BattleSideView = SideViewScene.instantiate()
	_tree.root.add_child(view)
	await _tree.process_frame
	view.setup(controller, "side_a", skill_db)

	var slime_id := instances_a[0].instance_id
	var sprite := view._arena.get_sprite(slime_id)

	view._arena.show_floating_text(slime_id, "Miss!", BattleArena3D.MISS_TEXT_COLOR)
	var new_label: Label3D = null
	for child in sprite.get_children():
		if child is Label3D and child.text == "Miss!":
			new_label = child
	_check("show_floating_text adds a Label3D with the right text as a child of the target sprite", new_label != null)
	_check("the floating text starts fully opaque", new_label != null and is_equal_approx(new_label.modulate.a, 1.0))

	await _tree.create_timer(BattleArena3D.FLOATING_TEXT_DURATION + 0.3).timeout
	_check("the floating text frees itself once its rise-and-fade finishes", not is_instance_valid(new_label))

	# An unknown/already-removed instance id is a harmless no-op, matching
	# animate_attack()/animate_faint()'s own convention.
	view._arena.show_floating_text(-999, "Critical!", BattleArena3D.CRITICAL_TEXT_COLOR)
	_check("floating text for an unknown instance id doesn't error", true)

	view.queue_free()

## A direct hit's floating callout is its damage NUMBER now, not just the
## bare word "Critical!" for a crit -- and a poison tick gets the same
## treatment in its own distinct color. Runs a real round through
## BattleController/_animate_event() (not show_floating_text() directly, see
## _check_floating_text() above) so this exercises the actual wiring, not
## just the underlying primitive.
func _check_damage_and_status_numbers(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var team_a := _make_team("Dmg Number A", [["slime", ["attack"]]])
	var team_b := _make_team("Dmg Number B", [["golem", ["attack"]]])
	var instances_a := TeamToBattleBridge.build_team(team_a, "side_a", monster_db, skill_db, trait_db, 0)
	var instances_b := TeamToBattleBridge.build_team(team_b, "side_b", monster_db, skill_db, trait_db, 100)
	var controller := BattleController.new(instances_a, instances_b, skill_db.skills_by_id)

	var view: BattleSideView = SideViewScene.instantiate()
	_tree.root.add_child(view)
	await _tree.process_frame
	view.setup(controller, "side_a", skill_db)

	var golem_id := instances_b[0].instance_id
	var golem_sprite := view._arena.get_sprite(golem_id)

	controller.submit_fight("side_a", 0, "attack", golem_id)
	controller.submit_fight("side_b", 0, "attack", instances_a[0].instance_id)
	await _tree.create_timer(2 * (BattleArena3D.LUNGE_OUT_TIME + BattleArena3D.LUNGE_BACK_TIME) + 0.1).timeout

	# Strips a possible "Critical!\n" prefix first so this passes whether or
	# not the hit happened to crit -- the point being tested is that a real
	# number shows up, not which exact callout variant this seed produces.
	var found_number := false
	for child in golem_sprite.get_children():
		if child is Label3D and (child as Label3D).text.replace("Critical!\n", "").is_valid_int():
			found_number = true
	_check("a resolved hit shows a numeric damage callout over the target", found_number)

	view.queue_free()

	var team_c := _make_team("Poison Number A", [["slime", ["attack"]]])
	var instances_c := TeamToBattleBridge.build_team(team_c, "side_a", monster_db, skill_db, trait_db, 0)
	var controller_c := BattleController.new(instances_c, instances_b, skill_db.skills_by_id)
	var view_c: BattleSideView = SideViewScene.instantiate()
	_tree.root.add_child(view_c)
	await _tree.process_frame
	view_c.setup(controller_c, "side_a", skill_db)

	var poison := skill_db.get_status("poison")
	instances_c[0].active_status = StatusInstance.new(poison)
	var tick_event := StatusTickEvent.new(instances_c[0].instance_id, poison.id, 7, instances_c[0].current_hp - 7, false)
	await view_c._animate_event(tick_event)
	var slime_sprite_c := view_c._arena.get_sprite(instances_c[0].instance_id)
	var found_poison_number := false
	for child in slime_sprite_c.get_children():
		if child is Label3D and (child as Label3D).text == "7" and (child as Label3D).modulate.is_equal_approx(BattleArena3D.STATUS_DAMAGE_TEXT_COLOR):
			found_poison_number = true
	_check("a poison tick shows its damage amount above the afflicted monster's own head", found_poison_number)

	view_c.queue_free()

## The Defend command: visible alongside Fight/Forfeit, halves damage
## once the round actually resolves (submission alone only queues the
## action -- see ActionExecutor.execute()), and the acting monster's own
## card marks it as "(Defending)" until its next action.
func _check_defend_button(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase) -> void:
	var team_a := _make_team("Defend UI A", [["slime", ["attack"]]])
	var team_b := _make_team("Defend UI B", [["golem", ["attack"]]])
	var instances_a := TeamToBattleBridge.build_team(team_a, "side_a", monster_db, skill_db, trait_db, 0)
	var instances_b := TeamToBattleBridge.build_team(team_b, "side_b", monster_db, skill_db, trait_db, 100)
	var controller := BattleController.new(instances_a, instances_b, skill_db.skills_by_id)

	var view: BattleSideView = SideViewScene.instantiate()
	_tree.root.add_child(view)
	await _tree.process_frame
	view.setup(controller, "side_a", skill_db)

	_check("the defend button is visible on the main command screen", view._defend_button.visible)
	view._on_fight_pressed()
	_check("the defend button is hidden while browsing the Fight menu", not view._defend_button.visible)
	view._on_actions_back_pressed()
	_check("the defend button reappears after backing out of the Fight menu", view._defend_button.visible)

	view._on_defend_pressed()
	controller.submit_fight("side_b", 0, "attack", instances_a[0].instance_id)
	await _tree.create_timer(2 * (BattleArena3D.LUNGE_OUT_TIME + BattleArena3D.LUNGE_BACK_TIME) + 0.3).timeout
	_check("defending sets is_defending on the actor once the round resolves", instances_a[0].is_defending)

	var card := view._build_monster_card(instances_a[0], true)
	var header: HBoxContainer = card.get_child(0).get_child(0)
	var name_label: Label = header.get_child(1)
	_check("a defending monster's card shows a (Defending) marker", name_label.text.ends_with("(Defending)"))

	view.queue_free()

func _find_texture_rect_with_tooltip(root: Node, tooltip_prefix: String) -> TextureRect:
	for child in root.get_children():
		if child is TextureRect and (child as TextureRect).tooltip_text.begins_with(tooltip_prefix):
			return child
		var found := _find_texture_rect_with_tooltip(child, tooltip_prefix)
		if found != null:
			return found
	return null

func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		print("FAIL: %s" % label)
		_all_passed = false
