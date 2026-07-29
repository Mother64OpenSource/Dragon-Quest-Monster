class_name NetworkLockstepTestRunner
extends RefCounted

## Online play (see game/net/) relies on a specific property of the battle
## engine: two independently-driven BattleController instances, given the
## same seed and the same two teams, must produce byte-identical results
## even if the *order* in which each instance's submit_fight/submit_swap
## calls happen to arrive differs (exactly what real network jitter would
## cause -- whichever peer's packet for a round's last action arrives first
## resolves that round on its own machine a few ms sooner, with no other
## effect). This is a direct extension of battle_test_runner.gd's existing
## "same seed -> same log" check, verifying the specific new claim online
## play depends on: submission *call order* across two independently-driven
## instances doesn't matter, only which actions were submitted -- because
## TurnManager.run_turn() always assigns submission_index by iterating
## ["side_a","side_b"] in fixed canonical order, never by call/arrival time.
## No ENet, no NetworkManager, no real networking of any kind is involved.

const SEED := 1357924680

var _all_passed := true

func run() -> bool:
	_all_passed = true
	var monster_db := MonsterDatabase.new()
	var skill_db := SkillDatabase.new()
	var trait_db := TraitDatabase.new()
	var skillset_db := SkillSetDatabase.new()

	_check_submission_order_independence(monster_db, skill_db, trait_db, skillset_db)
	_check_team_dict_round_trip(monster_db, skill_db, trait_db, skillset_db)
	_check_profile_dict_round_trip()

	if _all_passed:
		print("NetworkLockstepTestRunner: ALL CHECKS PASSED")
	else:
		print("NetworkLockstepTestRunner: SOME CHECKS FAILED")
	return _all_passed

## Each entry is [species_id, skill_point_allocation] -- see the identical
## helper in battle_ui_test_runner.gd for why there's no separate "equip a
## skill" step anymore.
func _make_team(team_name: String, entries: Array) -> SavedTeam:
	var team := SavedTeam.new()
	team.id = team_name
	team.team_name = team_name
	var members: Array[MonsterLoadout] = []
	for entry in entries:
		var loadout := MonsterLoadout.new()
		loadout.species_id = entry[0]
		loadout.skill_point_allocation = (entry[1] as Dictionary).duplicate()
		members.append(loadout)
	team.members = members
	return team

func _build_controller(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase, skillset_db: SkillSetDatabase, team_a: SavedTeam, team_b: SavedTeam) -> BattleController:
	var instances_a := TeamToBattleBridge.build_team(team_a, "side_a", monster_db, skill_db, trait_db, skillset_db, 0)
	var instances_b := TeamToBattleBridge.build_team(team_b, "side_b", monster_db, skill_db, trait_db, skillset_db, team_a.members.size())
	return BattleController.new(instances_a, instances_b, skill_db.skills_by_id, SEED)

## Two controllers, same seed + same two teams, but controller_a always
## submits side_a-then-side_b each round while controller_b always submits
## side_b-then-side_a -- the opposite call order, simulating two peers
## whose local UI/network arrival timing differs. If online play's core
## assumption holds, both must still reach identical results.
func _check_submission_order_independence(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase, skillset_db: SkillSetDatabase) -> void:
	var team_a := _make_team("Lockstep A", [["slime", {}]])
	var team_b := _make_team("Lockstep B", [["golem", {}]])

	var controller_a := _build_controller(monster_db, skill_db, trait_db, skillset_db, team_a, team_b)
	var controller_b := _build_controller(monster_db, skill_db, trait_db, skillset_db, team_a, team_b)

	var log_a: Array = []
	var log_b: Array = []
	controller_a.engine.get_event_bus().event_emitted.connect(func(event: BattleEvent) -> void: log_a.append(event.to_dict()))
	controller_b.engine.get_event_bus().event_emitted.connect(func(event: BattleEvent) -> void: log_b.append(event.to_dict()))

	var turns := 0
	while (not controller_a.is_over() or not controller_b.is_over()) and turns < 100:
		if not controller_a.is_over():
			var a_side_a := controller_a.get_state().get_monster_at("side_a", 0)
			var a_side_b := controller_a.get_state().get_monster_at("side_b", 0)
			controller_a.submit_fight("side_a", 0, "attack", a_side_b.instance_id)
			controller_a.submit_fight("side_b", 0, "attack", a_side_a.instance_id)
		if not controller_b.is_over():
			var b_side_a := controller_b.get_state().get_monster_at("side_a", 0)
			var b_side_b := controller_b.get_state().get_monster_at("side_b", 0)
			controller_b.submit_fight("side_b", 0, "attack", b_side_a.instance_id)
			controller_b.submit_fight("side_a", 0, "attack", b_side_b.instance_id)
		turns += 1

	_check("both independently-driven controllers reach battle_ended", controller_a.is_over() and controller_b.is_over())
	_check("winner_side matches across both controllers", controller_a.get_state().winner_side == controller_b.get_state().winner_side)
	_check("event logs are byte-identical despite different submission call order", log_a == log_b and not log_a.is_empty())

## Sanity check that the exact serialization online play will use to
## exchange teams (SavedTeamLoader.to_dict/load_from_dict, a Dictionary
## being directly RPC-transmittable) round-trips to identical
## MonsterInstance data through the same bridge function both peers use --
## with no real RPC involved.
func _check_team_dict_round_trip(monster_db: MonsterDatabase, skill_db: SkillDatabase, trait_db: TraitDatabase, skillset_db: SkillSetDatabase) -> void:
	var original := _make_team("RoundTrip", [["slime", {"slimer": 2}], ["golem", {}]])
	var dict := SavedTeamLoader.to_dict(original)
	var reconstructed := SavedTeamLoader.load_from_dict(dict)

	var original_instances := TeamToBattleBridge.build_team(original, "side_a", monster_db, skill_db, trait_db, skillset_db, 0)
	var reconstructed_instances := TeamToBattleBridge.build_team(reconstructed, "side_a", monster_db, skill_db, trait_db, skillset_db, 0)

	_check("team dict round-trip produces the same number of instances", original_instances.size() == reconstructed_instances.size())

	var all_match := original_instances.size() == reconstructed_instances.size()
	for i in range(min(original_instances.size(), reconstructed_instances.size())):
		var o: MonsterInstance = original_instances[i]
		var r: MonsterInstance = reconstructed_instances[i]
		if o.species.id != r.species.id or o.instance_id != r.instance_id:
			all_match = false
		var o_skill_ids: Array = []
		for skill in o.learned_skills:
			o_skill_ids.append(skill.id)
		var r_skill_ids: Array = []
		for skill in r.learned_skills:
			r_skill_ids.append(skill.id)
		if o_skill_ids != r_skill_ids:
			all_match = false
	_check("team dict round-trip produces identical MonsterInstance data (species, id, skills)", all_match)

## Same idea as _check_team_dict_round_trip(), for the profile handshake
## added alongside team/seed (see NetworkManager.send_local_profile()) --
## the only piece of that exchange meaningfully checkable without a real
## ENet socket pair (see wiki/log.md's "real sockets can't be driven
## headlessly" note).
func _check_profile_dict_round_trip() -> void:
	var original := PlayerProfile.new()
	original.player_name = "Eli"
	original.avatar_species_id = "golem"
	var reconstructed := PlayerProfileLoader.load_from_dict(PlayerProfileLoader.to_dict(original))
	_check("profile dict round-trip preserves player_name", reconstructed.player_name == original.player_name)
	_check("profile dict round-trip preserves avatar_species_id", reconstructed.avatar_species_id == original.avatar_species_id)

func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		print("FAIL: %s" % label)
		_all_passed = false
