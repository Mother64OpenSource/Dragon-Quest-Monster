class_name BattleTestRunner
extends RefCounted

## Runs the M1 scripted battle (see ScriptedTurns) end-to-end and asserts:
## (1) it resolves within a turn cap, (2) the expected winner/turn count,
## (3) hand-computed damage/status/faint numbers via a full event-log scan,
## (4) running the same seed twice produces byte-identical serialized event
## logs. Also sanity-checks DeterministicRng itself is reproducible.
##
## Known scope limits of this specific script (still valid, loadable
## fixtures — just not exercised by this particular run): HealEffect, the
## debuff direction of StatModEffect, magic damage, HealSlime, status
## skip-turn chance, and full status expiry.

const SEED := 918273645
const MAX_TURNS := 20

var _all_passed := true

func run() -> bool:
	_all_passed = true

	var run1 := _run_once(true)
	var run2 := _run_once(false)

	_check("battle resolved within turn cap", run1.result.completed)
	_check("winner is side_b", run1.result.winner_side == "side_b")
	_check("turns_run == 4", run1.result.turns_run == 4)
	_check("golem final hp == 27", run1.golem_final_hp == 27)

	_assert_expected_events(run1.events, run1.slime, run1.dracky, run1.golem)

	_check("re-run with same seed produces identical event log length", run1.events.size() == run2.events.size())
	var logs_match := true
	if run1.events.size() == run2.events.size():
		for i in range(run1.events.size()):
			if run1.events[i].to_dict() != run2.events[i].to_dict():
				logs_match = false
				break
	else:
		logs_match = false
	_check("re-run with same seed produces identical event log contents", logs_match)

	_check_rng_determinism()

	if _all_passed:
		print("BattleTestRunner: ALL CHECKS PASSED")
	else:
		print("BattleTestRunner: SOME CHECKS FAILED")
	return _all_passed

func _run_once(verbose: bool) -> Dictionary:
	var team_builder := TeamBuilder.new()
	var side_a_team := team_builder.build_team(["slime", "dracky"], "side_a")
	var side_b_team := team_builder.build_team(["golem"], "side_b")

	var slime := side_a_team[0]
	var dracky := side_a_team[1]
	var golem := side_b_team[0]

	var providers := ScriptedTurns.build_providers(slime, dracky, golem)
	var engine := BattleEngine.new(side_a_team, side_b_team, SEED, providers, team_builder.skill_registry, 1)

	var logged_events: Array[BattleEvent] = []
	engine.get_event_bus().event_emitted.connect(func(event: BattleEvent) -> void:
		logged_events.append(event)
		if verbose:
			print(_format_event(event))
	)

	engine.start_battle()
	var result := engine.run_to_completion(MAX_TURNS)

	return {
		"result": result,
		"events": logged_events,
		"golem_final_hp": golem.current_hp,
		"slime": slime,
		"dracky": dracky,
		"golem": golem,
	}

func _assert_expected_events(events: Array[BattleEvent], slime: MonsterInstance, dracky: MonsterInstance, golem: MonsterInstance) -> void:
	var damage_events: Array[DamageAppliedEvent] = []
	var status_tick_events: Array[StatusTickEvent] = []
	var stat_changed_events: Array[StatChangedEvent] = []
	var fainted_events: Array[MonsterFaintedEvent] = []
	var entered_events: Array[MonsterEnteredEvent] = []
	var status_applied_events: Array[StatusAppliedEvent] = []
	var ended_events: Array[BattleEndedEvent] = []

	for event in events:
		if event is DamageAppliedEvent:
			damage_events.append(event)
		elif event is StatusTickEvent:
			status_tick_events.append(event)
		elif event is StatChangedEvent:
			stat_changed_events.append(event)
		elif event is MonsterFaintedEvent:
			fainted_events.append(event)
		elif event is MonsterEnteredEvent:
			entered_events.append(event)
		elif event is StatusAppliedEvent:
			status_applied_events.append(event)
		elif event is BattleEndedEvent:
			ended_events.append(event)

	_check("exactly 7 DamageAppliedEvents", damage_events.size() == 7)
	if damage_events.size() == 7:
		_check("dmg0: golem attack -> slime, 24 (hp26)", _dmg_matches(damage_events[0], 24, 26, slime.instance_id))
		_check("dmg1: slime attack -> golem, 10 (hp40)", _dmg_matches(damage_events[1], 10, 40, golem.instance_id))
		_check("dmg2: golem double_slash hit1 -> slime, 17 (hp9)", _dmg_matches(damage_events[2], 17, 9, slime.instance_id))
		_check("dmg3: golem double_slash hit2 -> slime, 9 (hp0, fatal)", _dmg_matches(damage_events[3], 9, 0, slime.instance_id))
		_check("dmg4: golem attack -> dracky, 24 (hp21)", _dmg_matches(damage_events[4], 24, 21, dracky.instance_id))
		_check("dmg5: dracky attack -> golem, 7 (hp27)", _dmg_matches(damage_events[5], 7, 27, golem.instance_id))
		_check("dmg6: golem attack -> dracky, 21 (hp0, fatal)", _dmg_matches(damage_events[6], 21, 0, dracky.instance_id))

	_check("exactly 1 StatusTickEvent (golem poison)", status_tick_events.size() == 1)
	if status_tick_events.size() == 1:
		var tick := status_tick_events[0]
		_check("poison tick: 6 dmg -> golem hp34, not expired", tick.damage == 6 and tick.resulting_hp == 34 and not tick.expired and tick.target_instance_id == golem.instance_id)

	_check("exactly 1 StatChangedEvent (slime oomph)", stat_changed_events.size() == 1)
	if stat_changed_events.size() == 1:
		var stat_change := stat_changed_events[0]
		_check("oomph: attack stage 0 -> 1 on slime", stat_change.stat_name == "attack" and stat_change.delta_applied == 1 and stat_change.new_stage == 1 and stat_change.target_instance_id == slime.instance_id)

	_check("exactly 2 MonsterFaintedEvents (slime then dracky)", fainted_events.size() == 2)
	if fainted_events.size() == 2:
		_check("slime faints before dracky", fainted_events[0].instance_id == slime.instance_id and fainted_events[1].instance_id == dracky.instance_id)

	_check("exactly 3 MonsterEnteredEvents (initial slime/golem + dracky backfill)", entered_events.size() == 3)
	if entered_events.size() == 3:
		_check("dracky backfills side_a slot0", entered_events[2].instance_id == dracky.instance_id and entered_events[2].side == "side_a" and entered_events[2].slot == 0)

	_check("exactly 1 StatusAppliedEvent (poison on golem)", status_applied_events.size() == 1)
	if status_applied_events.size() == 1:
		_check("poison applied to golem", status_applied_events[0].target_instance_id == golem.instance_id and status_applied_events[0].status_id == "poison")

	_check("exactly 1 BattleEndedEvent, side_b wins", ended_events.size() == 1 and ended_events[0].winner_side == "side_b")

func _dmg_matches(event: DamageAppliedEvent, amount: int, resulting_hp: int, target_instance_id: int) -> bool:
	return event.amount == amount and event.resulting_hp == resulting_hp and event.target_instance_id == target_instance_id

func _check_rng_determinism() -> void:
	var rng_a := DeterministicRng.new(42)
	var rng_b := DeterministicRng.new(42)
	var samples_match := true
	for i in range(50):
		if rng_a.randi_range(0, 1000) != rng_b.randi_range(0, 1000):
			samples_match = false
			break
	_check("two DeterministicRng instances with the same seed produce identical sequences", samples_match)

func _format_event(event: BattleEvent) -> String:
	return "[T%d] %s" % [event.turn_number, JSON.stringify(event.to_dict())]

func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		print("FAIL: %s" % label)
		_all_passed = false
