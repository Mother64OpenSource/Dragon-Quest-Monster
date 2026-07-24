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
	_check("golem final hp == 11", run1.golem_final_hp == 11)

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
	_check_trait_mechanics()
	_check_priority_mechanics()
	_check_crit_mechanics()
	_check_dodge_mechanics()
	_check_counter_mechanics()
	_check_tension_mechanics()
	_check_defend_mechanics()

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
		_check("dmg1: slime attack -> golem, 20 (hp30)", _dmg_matches(damage_events[1], 20, 30, golem.instance_id))
		_check("dmg2: golem double_slash hit1 -> slime, 17 (hp9)", _dmg_matches(damage_events[2], 17, 9, slime.instance_id))
		_check("dmg3: golem double_slash hit2 -> slime, 9 (hp0, fatal)", _dmg_matches(damage_events[3], 9, 0, slime.instance_id))
		_check("dmg4: golem attack -> dracky, 24 (hp21)", _dmg_matches(damage_events[4], 24, 21, dracky.instance_id))
		_check("dmg5: dracky attack -> golem, 13 (hp11)", _dmg_matches(damage_events[5], 13, 11, golem.instance_id))
		_check("dmg6: golem attack -> dracky, 21 (hp0, fatal)", _dmg_matches(damage_events[6], 21, 0, dracky.instance_id))

	_check("exactly 1 StatusTickEvent (golem poison)", status_tick_events.size() == 1)
	if status_tick_events.size() == 1:
		var tick := status_tick_events[0]
		_check("poison tick: 6 dmg -> golem hp24, not expired", tick.damage == 6 and tick.resulting_hp == 24 and not tick.expired and tick.target_instance_id == golem.instance_id)

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

## Real per-monster trait data was imported from the project's spreadsheet
## (see wiki/log.md); most of ~215 real trait names still describe mechanics
## this engine has no subsystem for at all (e.g. flee, or manipulating an
## opposing side's tension), so they load as metadata-only via
## TraitEffect.create()'s no-op fallback. Only a handful with an explicit
## sheet-given numeric magnitude, for one of the subsystems this engine DOES
## model (crit/dodge/counter/turn-order/tension/Defend), got real generic
## TraitEffect subclasses -- tested directly here as pure functions,
## same philosophy as _effective_accuracy() above, rather than threaded
## through a full scripted battle.
func _check_trait_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	var fallback_data := TraitData.new()
	fallback_data.id = "small_body"
	var fallback_effect := TraitEffect.create("small_body", fallback_data)
	_check("unknown trait id (no bespoke case) falls back to a plain no-op TraitEffect, not null", fallback_effect != null and fallback_effect.get_script() == TraitEffect)

	var slime_side := team_builder.build_team(["slime"], "side_a")
	_check("slime's 3 metadata-only starting traits all load into active_traits with no errors", slime_side[0].active_traits.size() == 3)

	var light := DamageReductionTraitEffect.new()
	light.damage_reduction_percent = 0.5
	_check("light metal body: 100 dmg -> 50 (half damage)", light.on_before_damage_taken(null, null, null, 100) == 50)
	var hard := DamageReductionTraitEffect.new()
	hard.damage_reduction_percent = 0.75
	_check("hard metal body: 100 dmg -> 25 (quarter damage)", hard.on_before_damage_taken(null, null, null, 100) == 25)
	var superhard := DamageReductionTraitEffect.new()
	superhard.damage_reduction_percent = 0.8
	_check("superhard metal body: 100 dmg -> 20 (fifth damage)", superhard.on_before_damage_taken(null, null, null, 100) == 20)

	var recovery_team := team_builder.build_team(["slime"], "side_a")
	var recovering_slime := recovery_team[0]
	recovering_slime.current_hp = 1
	var recovery := TurnEndHpDeltaTraitEffect.new()
	recovery.percent_of_max = 0.06
	recovery.on_turn_end(null, recovering_slime)
	var expected_heal := maxi(1, MathUtils.round_half_up(float(recovering_slime.species.base_hp) * 0.06))
	_check("steady recovery heals a % of max HP at turn end", recovering_slime.current_hp == mini(recovering_slime.species.base_hp, 1 + expected_heal))

	var regen_team := team_builder.build_team(["slime"], "side_a")
	var regen_slime := regen_team[0]
	regen_slime.current_mp = 0
	var regen := TurnEndMpDeltaTraitEffect.new()
	regen.percent_of_max = 0.1
	regen.on_turn_end(null, regen_slime)
	var expected_regen := maxi(1, MathUtils.round_half_up(float(regen_slime.species.base_mp) * 0.1))
	_check("magic regenerator restores a % of max MP at turn end", regen_slime.current_mp == mini(regen_slime.species.base_mp, expected_regen))

	var drain_team := team_builder.build_team(["slime"], "side_a")
	var drain_slime := drain_team[0]
	var drain := TurnEndMpDeltaTraitEffect.new()
	drain.percent_of_max = -0.08
	drain.on_turn_end(null, drain_slime)
	var expected_drain := maxi(1, MathUtils.round_half_up(float(drain_slime.species.base_mp) * 0.08))
	_check("disenchanted drains a % of max MP at turn end", drain_slime.current_mp == maxi(0, drain_slime.species.base_mp - expected_drain))

	var bonus := BonusDamageVsMetalBodyTraitEffect.new()
	bonus.flat_bonus = 1
	var metal_slime_side := team_builder.build_team(["metal_slime"], "side_b")
	_check("hunter mech: +1 dmg vs a target carrying a metal-body trait", bonus.on_before_damage_dealt(null, null, metal_slime_side[0], 10) == 11)
	var dracky_side := team_builder.build_team(["dracky"], "side_b")
	_check("hunter mech: no bonus vs a target without a metal-body trait", bonus.on_before_damage_dealt(null, null, dracky_side[0], 10) == 10)

## Priority ordering is tested relative to whichever actor turns out to be
## "baseline first" (raw agility + skill priority, no traits) rather than
## assuming which of slime/golem is faster -- that's real fixture data this
## test shouldn't need to hardcode an assumption about.
func _check_priority_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	var side_a := team_builder.build_team(["slime"], "side_a")
	var side_b := team_builder.build_team(["golem"], "side_b")
	var actor_a := side_a[0]
	var actor_b := side_b[0]
	var event_bus := BattleEventBus.new()
	var state := BattleState.new(DeterministicRng.new(1), event_bus)
	state.side_a_team = side_a
	state.side_b_team = side_b
	state.set_active_at("side_a", 0, 0)
	state.set_active_at("side_b", 0, 0)

	var action_a := Action.new(actor_a.instance_id, "attack", actor_b.instance_id)
	var action_b := Action.new(actor_b.instance_id, "attack", actor_a.instance_id)

	var baseline := ActionResolver.resolve_order([action_a, action_b], state, team_builder.skill_registry)
	var baseline_first: MonsterInstance = actor_a if baseline[0].actor_instance_id == actor_a.instance_id else actor_b
	var baseline_second: MonsterInstance = actor_b if baseline_first == actor_a else actor_a

	var early_bird := PriorityBonusTraitEffect.new()
	early_bird.priority_bonus = 100
	var early_bird_traits: Array[TraitEffect] = [early_bird]
	baseline_second.active_traits = early_bird_traits
	var with_early_bird := ActionResolver.resolve_order([action_a, action_b], state, team_builder.skill_registry)
	_check("early bird overrides being slower at baseline", with_early_bird[0].actor_instance_id == baseline_second.instance_id)

	var ultra := PriorityBonusTraitEffect.new()
	ultra.priority_bonus = 200
	var ultra_traits: Array[TraitEffect] = [ultra]
	baseline_first.active_traits = ultra_traits
	var with_ultra := ActionResolver.resolve_order([action_a, action_b], state, team_builder.skill_registry)
	_check("ultra fast action (+200) sorts before early bird (+100)", with_ultra[0].actor_instance_id == baseline_first.instance_id)

	var last_word := PriorityBonusTraitEffect.new()
	last_word.priority_bonus = -100
	var last_word_traits: Array[TraitEffect] = [last_word]
	baseline_first.active_traits = last_word_traits
	baseline_second.active_traits = [] as Array[TraitEffect]
	var with_last_word := ActionResolver.resolve_order([action_a, action_b], state, team_builder.skill_registry)
	_check("last word sorts after a normal-priority actor", with_last_word[1].actor_instance_id == baseline_first.instance_id)

## Crit mechanics tested as pure functions against hand-computed values,
## same philosophy as _check_status_mechanics()'s dazzle checks -- no
## reliance on a real RNG roll landing a certain way.
func _check_crit_mechanics() -> void:
	_check("crit formula: ignoring defense gives strictly more damage than not", DamageFormula.calculate(10, 100, 0) > DamageFormula.calculate(10, 100, 50))

	var massacre := CritChanceMultiplierTraitEffect.new()
	massacre.multiplier = 2.0
	massacre.category_filter = -1
	_check("critical massacre doubles physical crit chance", is_equal_approx(massacre.get_crit_chance_multiplier(null, DamageEffect.Category.PHYSICAL), 2.0))
	_check("critical massacre doubles magic crit chance too (category_filter -1 = all)", is_equal_approx(massacre.get_crit_chance_multiplier(null, DamageEffect.Category.MAGIC), 2.0))

	var spell_satisfaction := CritChanceMultiplierTraitEffect.new()
	spell_satisfaction.multiplier = 2.0
	spell_satisfaction.category_filter = DamageEffect.Category.MAGIC
	_check("spell satisfaction only doubles magic crit chance", is_equal_approx(spell_satisfaction.get_crit_chance_multiplier(null, DamageEffect.Category.MAGIC), 2.0))
	_check("spell satisfaction leaves physical crit chance alone", is_equal_approx(spell_satisfaction.get_crit_chance_multiplier(null, DamageEffect.Category.PHYSICAL), 1.0))

	_check("full satisfaction guard blocks crits", FullSatisfactionGuardTraitEffect.new().blocks_critical_hits())

	var team_builder := TeamBuilder.new()
	var desperado_slime := team_builder.build_team(["slime"], "side_a")[0]
	var desperado := DesperadoTraitEffect.new()
	desperado.hp_threshold_percent = 0.25
	desperado.multiplier_when_low = 2.0
	desperado_slime.current_hp = desperado_slime.species.base_hp
	_check("desperado: no bonus at full HP", is_equal_approx(desperado.get_crit_chance_multiplier(desperado_slime, DamageEffect.Category.PHYSICAL), 1.0))
	desperado_slime.current_hp = maxi(1, MathUtils.round_half_up(float(desperado_slime.species.base_hp) * 0.2))
	_check("desperado: doubled crit chance at low HP", is_equal_approx(desperado.get_crit_chance_multiplier(desperado_slime, DamageEffect.Category.PHYSICAL), 2.0))

	var hopeful := HopefulHitterTraitEffect.new()
	hopeful.accuracy_multiplier = 0.75
	hopeful.crit_multiplier = 2.0
	_check("hopeful hitter lowers accuracy", is_equal_approx(hopeful.get_accuracy_multiplier(), 0.75))
	_check("hopeful hitter raises crit chance", is_equal_approx(hopeful.get_crit_chance_multiplier(null, DamageEffect.Category.PHYSICAL), 2.0))

## Both "dodge" and "block" reuse the existing on_before_damage_taken hook
## (return 0) -- chance=1.0/0.0 exercise DeterministicRng.chance()'s
## documented boundary short-circuit, same trick used throughout this file.
func _check_dodge_mechanics() -> void:
	var team_builder := TeamBuilder.new()
	var harness := _new_harness(team_builder)

	var dodge := ChanceBasedDamageNegationTraitEffect.new()
	dodge.chance = 1.0
	_check("chance=1.0 deterministically negates damage", dodge.on_before_damage_taken(harness.ctx, harness.target, harness.actor, 50) == 0)

	var blocked_dodge := ChanceBasedDamageNegationTraitEffect.new()
	blocked_dodge.chance = 1.0
	blocked_dodge.blocked_by_trait_id = "fly_swatter"
	var fly_swatter_data := TraitData.new()
	fly_swatter_data.id = "fly_swatter"
	var fly_swatter_effect := TraitEffect.new()
	fly_swatter_effect.trait_data = fly_swatter_data
	var fly_swatter_traits: Array[TraitEffect] = [fly_swatter_effect]
	harness.actor.active_traits = fly_swatter_traits
	_check("fly swatter suppresses the dodge roll even at chance=1.0", blocked_dodge.on_before_damage_taken(harness.ctx, harness.target, harness.actor, 50) == 50)

	var perilous := ChanceBasedDamageNegationTraitEffect.new()
	perilous.chance = 0.0
	perilous.damage_multiplier_otherwise = 1.5
	_check("perilous parrier: a failed block (chance=0.0) increases damage instead", perilous.on_before_damage_taken(harness.ctx, harness.target, harness.actor, 100) == 150)

## Counter hooks are called directly (bypassing DamageEffect.apply()
## entirely), so there's no crit-roll randomness to guard against here.
func _check_counter_mechanics() -> void:
	var team_builder := TeamBuilder.new()
	var harness := _new_harness(team_builder)

	var counter := CounterAttackTraitEffect.new()
	counter.counter_chance = 1.0
	counter.also_negates_damage = false
	var expected_counter_damage := DamageFormula.calculate(0, harness.target.get_effective_stat("attack"), harness.actor.get_effective_stat("defense"))
	var attacker_hp_before: int = harness.actor.current_hp
	var result := counter.on_before_damage_taken(harness.ctx, harness.target, harness.actor, 40)
	_check("counter striker: original damage passes through unchanged", result == 40)
	_check("counter striker: attacker takes the hand-computed counter damage", harness.actor.current_hp == attacker_hp_before - expected_counter_damage)
	var saw_counter_event := false
	for event in harness.ctx.event_bus.get_log():
		if event is CounterattackEvent and event.amount == expected_counter_damage:
			saw_counter_event = true
	_check("counter striker emits a CounterattackEvent with the right amount", saw_counter_event)

	var perfect_parry := CounterAttackTraitEffect.new()
	perfect_parry.counter_chance = 1.0
	perfect_parry.also_negates_damage = true
	_check("perfect parry: negates the original damage too", perfect_parry.on_before_damage_taken(harness.ctx, harness.target, harness.actor, 40) == 0)

	# The real gap this design closes: EndOfTurnProcessor's own fainted pass
	# skips monsters that are ALREADY fainted, so a monster fainted mid-hook
	# via counter would never get its MonsterFaintedEvent without the
	# explicit FaintHandler.handle_if_fainted() call inside the trait itself.
	var lethal_harness := _new_harness(team_builder)
	lethal_harness.actor.current_hp = 1
	var lethal_counter := CounterAttackTraitEffect.new()
	lethal_counter.counter_chance = 1.0
	lethal_counter.on_before_damage_taken(lethal_harness.ctx, lethal_harness.target, lethal_harness.actor, 10)
	_check("a lethal counter actually faints the attacker", lethal_harness.actor.is_fainted())
	var saw_fainted := false
	for event in lethal_harness.ctx.event_bus.get_log():
		if event is MonsterFaintedEvent and event.instance_id == lethal_harness.actor.instance_id:
			saw_fainted = true
	_check("a lethal counter emits MonsterFaintedEvent, not just silently zeroing HP", saw_fainted)

## The target carries FullSatisfactionGuardTraitEffect for the damage-
## integration part specifically to neutralize the independent crit roll
## DamageEffect.apply() also makes on every hit -- this test is about
## tension's snapshot/reset-once behavior, not crit, and shouldn't have its
## expected numbers depend on how a real RNG roll happens to land.
func _check_tension_mechanics() -> void:
	var team_builder := TeamBuilder.new()
	var harness := _new_harness(team_builder)

	var gain := ChanceBasedTensionGainTraitEffect.new()
	gain.chance = 1.0
	gain.levels = 1
	harness.actor.tension_level = 0
	gain.on_turn_start(harness.ctx, harness.actor)
	_check("tension gain: +1 level at chance=1.0", harness.actor.tension_level == 1)
	harness.actor.tension_level = 4
	gain.on_turn_start(harness.ctx, harness.actor)
	_check("tension gain: capped at 4", harness.actor.tension_level == 4)

	var jump := HpGatedTensionJumpTraitEffect.new()
	jump.hp_threshold_percent = 0.25
	jump.target_level = 4
	harness.actor.tension_level = 0
	harness.actor.current_hp = harness.actor.species.base_hp
	jump.on_turn_start(harness.ctx, harness.actor)
	_check("wrath of the stars: no jump above the HP threshold", harness.actor.tension_level == 0)
	harness.actor.current_hp = maxi(1, MathUtils.round_half_up(float(harness.actor.species.base_hp) * 0.1))
	jump.on_turn_start(harness.ctx, harness.actor)
	_check("wrath of the stars: jumps to max level under the HP threshold", harness.actor.tension_level == 4)

	var heat_up := HeatUpTraitEffect.new()
	harness.actor.tension_level = 0
	heat_up.on_critical_hit_taken(harness.ctx, harness.actor, harness.target)
	_check("heat up: floor bump from 0", harness.actor.tension_level == 1)
	harness.actor.tension_level = 1
	heat_up.on_critical_hit_taken(harness.ctx, harness.actor, harness.target)
	_check("heat up: doubles from 1 to 2", harness.actor.tension_level == 2)

	var tension_harness := _new_harness(team_builder)
	tension_harness.actor.tension_level = 2
	tension_harness.actor.active_traits = [] as Array[TraitEffect]
	var guard_traits: Array[TraitEffect] = [FullSatisfactionGuardTraitEffect.new()]
	tension_harness.target.active_traits = guard_traits
	var multi_hit_skill := DamageEffect.new()
	multi_hit_skill.category = DamageEffect.Category.PHYSICAL
	multi_hit_skill.power = 0
	multi_hit_skill.min_hits = 2
	multi_hit_skill.max_hits = 2
	var offense: int = tension_harness.actor.get_effective_stat("attack")
	var defense: int = tension_harness.target.get_effective_stat("defense")
	var base_damage := DamageFormula.calculate(0, offense, defense)
	var expected_boosted := MathUtils.round_half_up(float(base_damage) * 1.5)
	multi_hit_skill.apply(tension_harness.ctx, tension_harness.actor, tension_harness.target)
	var dmg_events: Array[DamageAppliedEvent] = []
	for event in tension_harness.ctx.event_bus.get_log():
		if event is DamageAppliedEvent:
			dmg_events.append(event)
	_check("tension: exactly 2 hits recorded", dmg_events.size() == 2)
	if dmg_events.size() == 2:
		_check("tension: hit 1 gets the +50% (2 levels) boost", dmg_events[0].amount == expected_boosted)
		_check("tension: hit 2 ALSO gets the boost off the same snapshot, not reset mid-loop", dmg_events[1].amount == expected_boosted)
	_check("tension: resets to 0 exactly once after the action completes", tension_harness.actor.tension_level == 0)

## Defend halves incoming damage until the defender's own next action (see
## ActionExecutor.execute()/DamageEffect._run_damage_hooks()). Reuses the
## tension test's FullSatisfactionGuardTraitEffect trick to neutralize the
## independent crit roll DamageEffect.apply() always makes, so the expected
## halved amount doesn't depend on how a real RNG roll happens to land.
func _check_defend_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	var reset_harness := _new_harness(team_builder)
	ActionExecutor.execute(reset_harness.ctx, Action.new_defend(reset_harness.actor.instance_id), team_builder.skill_registry)
	_check("defend sets is_defending", reset_harness.actor.is_defending)
	var saw_defend_event := false
	for event in reset_harness.ctx.event_bus.get_log():
		if event is DefendEvent and event.actor_instance_id == reset_harness.actor.instance_id:
			saw_defend_event = true
	_check("defend emits a DefendEvent", saw_defend_event)

	ActionExecutor.execute(reset_harness.ctx, Action.new(reset_harness.actor.instance_id, "attack", reset_harness.target.instance_id), team_builder.skill_registry)
	_check("is_defending clears the moment this monster's own next action executes", not reset_harness.actor.is_defending)

	var damage_harness := _new_harness(team_builder)
	damage_harness.target.is_defending = true
	var guard_traits: Array[TraitEffect] = [FullSatisfactionGuardTraitEffect.new()]
	damage_harness.target.active_traits = guard_traits
	var skill := DamageEffect.new()
	skill.category = DamageEffect.Category.PHYSICAL
	skill.power = 10
	var offense: int = damage_harness.actor.get_effective_stat("attack")
	var defense: int = damage_harness.target.get_effective_stat("defense")
	var base_damage := DamageFormula.calculate(10, offense, defense)
	var expected_halved := MathUtils.round_half_up(float(base_damage) * DamageEffect.DEFEND_DAMAGE_MULTIPLIER)
	skill.apply(damage_harness.ctx, damage_harness.actor, damage_harness.target)
	var applied_amount := -1
	for event in damage_harness.ctx.event_bus.get_log():
		if event is DamageAppliedEvent:
			applied_amount = event.amount
	_check("defend halves incoming damage to the hand-computed amount", applied_amount == expected_halved)
	_check("defend's halved amount is strictly less than the undefended baseline", expected_halved < base_damage)

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
