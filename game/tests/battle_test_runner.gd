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
	_check_status_mechanics()

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

## Real DQ status mechanics (see wiki/log.md): a full-body condition
## (skip_turn_chance) can prevent acting regardless of the skill queued, a
## category seal (blocked_skill_category) only blocks that category (Attack
## always stays usable), Dazzle degrades physical-only accuracy, and Sleep
## clears itself the instant its bearer takes damage. skip_turn_chance/
## accuracy values of exactly 0.0/1.0 make every check below deterministic
## regardless of RNG seed (DeterministicRng.chance() short-circuits both
## boundaries -- see deterministic_rng.gd), so no statistical/flaky trials
## are needed.
func _check_status_mechanics() -> void:
	var team_builder := TeamBuilder.new()
	var attack: SkillData = team_builder.skill_registry.get("attack")
	var frizz: SkillData = team_builder.skill_registry.get("frizz")
	_check("fixtures needed for status tests exist (attack, frizz)", attack != null and frizz != null)
	if attack == null or frizz == null:
		return

	# 1. Immobilize (skip_turn_chance 1.0): always prevents acting entirely,
	# whatever skill was queued -- the target never takes damage.
	var immobilize := team_builder.skill_database.get_status("immobilize")
	var harness1 := _new_harness(team_builder)
	harness1.actor.active_status = StatusInstance.new(immobilize)
	ActionExecutor.execute(harness1.ctx, Action.new(harness1.actor.instance_id, "attack", harness1.target.instance_id), team_builder.skill_registry)
	var log1: Array[BattleEvent] = harness1.ctx.event_bus.get_log()
	_check("immobilize: exactly one event (the prevented attempt)", log1.size() == 1)
	if log1.size() == 1:
		var e1: SkillUsedEvent = log1[0]
		_check("immobilize: SkillUsedEvent flags prevented_by_status", e1 is SkillUsedEvent and e1.prevented_by_status == "immobilize")
	_check("immobilize: target takes no damage", harness1.target.current_hp == harness1.target.species.base_hp)

	# 2. Gobstop (blocked_skill_category "skill"): blocks a non-Attack skill
	# but leaves basic Attack usable.
	var gobstop := team_builder.skill_database.get_status("gobstop")
	var harness2 := _new_harness(team_builder)
	harness2.actor.active_status = StatusInstance.new(gobstop)
	ActionExecutor.execute(harness2.ctx, Action.new(harness2.actor.instance_id, "frizz", harness2.target.instance_id), team_builder.skill_registry)
	var log2: Array[BattleEvent] = harness2.ctx.event_bus.get_log()
	_check("gobstop: blocks a non-attack skill", log2.size() == 1 and log2[0] is SkillUsedEvent and log2[0].prevented_by_status == "gobstop")
	ActionExecutor.execute(harness2.ctx, Action.new(harness2.actor.instance_id, "attack", harness2.target.instance_id), team_builder.skill_registry)
	var log2b: Array[BattleEvent] = harness2.ctx.event_bus.get_log()
	_check("gobstop: still allows basic Attack (2 more events: used + damage)", log2b.size() == 3)
	if log2b.size() == 3:
		_check("gobstop: the Attack actually went through, no prevented flag", log2b[1] is SkillUsedEvent and log2b[1].prevented_by_status.is_empty() and not log2b[1].missed)

	# 3. Silence (blocked_skill_category "magic"): blocks a magic skill
	# (Frizz) but leaves basic Attack usable.
	var silence := team_builder.skill_database.get_status("silence")
	var harness3 := _new_harness(team_builder)
	harness3.actor.active_status = StatusInstance.new(silence)
	ActionExecutor.execute(harness3.ctx, Action.new(harness3.actor.instance_id, "frizz", harness3.target.instance_id), team_builder.skill_registry)
	var log3: Array[BattleEvent] = harness3.ctx.event_bus.get_log()
	_check("silence: blocks a magic skill", log3.size() == 1 and log3[0] is SkillUsedEvent and log3[0].prevented_by_status == "silence")
	ActionExecutor.execute(harness3.ctx, Action.new(harness3.actor.instance_id, "attack", harness3.target.instance_id), team_builder.skill_registry)
	var log3b: Array[BattleEvent] = harness3.ctx.event_bus.get_log()
	_check("silence: still allows basic Attack", log3b.size() == 3 and log3b[1] is SkillUsedEvent and log3b[1].prevented_by_status.is_empty())

	# 4. Dazzle's accuracy penalty is a pure function of (status, skill) --
	# tested directly rather than via probabilistic accuracy-roll trials.
	var dazzle := team_builder.skill_database.get_status("dazzle")
	_check("dazzle: halves a physical skill's accuracy", is_equal_approx(ActionExecutor._effective_accuracy(dazzle, attack), attack.accuracy * 0.5))
	_check("dazzle: leaves a magic skill's accuracy untouched", is_equal_approx(ActionExecutor._effective_accuracy(dazzle, frizz), frizz.accuracy))
	_check("no status: leaves accuracy untouched", is_equal_approx(ActionExecutor._effective_accuracy(null, attack), attack.accuracy))

	# 5. Sleep wakes on any damage taken, mid-effect -- not just at the
	# normal end-of-turn tick/expiry point.
	var sleep := team_builder.skill_database.get_status("sleep")
	var harness5 := _new_harness(team_builder)
	harness5.target.active_status = StatusInstance.new(sleep)
	ActionExecutor.execute(harness5.ctx, Action.new(harness5.actor.instance_id, "attack", harness5.target.instance_id), team_builder.skill_registry)
	_check("sleep: cleared the instant its bearer takes damage", harness5.target.active_status == null)
	var log5: Array[BattleEvent] = harness5.ctx.event_bus.get_log()
	var saw_wake_tick := false
	for event in log5:
		if event is StatusTickEvent and event.status_id == "sleep" and event.expired:
			saw_wake_tick = true
	_check("sleep: wake is narrated via a StatusTickEvent(expired=true)", saw_wake_tick)

## One fresh actor(side_a)/target(side_b) pair plus a real BattleContext,
## isolated per status scenario so one test's active_status/event log can't
## leak into another's.
func _new_harness(team_builder: TeamBuilder) -> Dictionary:
	var side_a := team_builder.build_team(["slime"], "side_a")
	var side_b := team_builder.build_team(["golem"], "side_b")
	var event_bus := BattleEventBus.new()
	var state := BattleState.new(DeterministicRng.new(1), event_bus)
	state.side_a_team = side_a
	state.side_b_team = side_b
	state.set_active_at("side_a", 0, 0)
	state.set_active_at("side_b", 0, 0)
	return {
		"ctx": BattleContext.new(state),
		"actor": side_a[0],
		"target": side_b[0],
	}

func _format_event(event: BattleEvent) -> String:
	return "[T%d] %s" % [event.turn_number, JSON.stringify(event.to_dict())]

func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		print("FAIL: %s" % label)
		_all_passed = false
