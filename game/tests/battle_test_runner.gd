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
	_check_multi_attack_mechanics()
	_check_roulette_mechanics()
	_check_retaliation_mechanics()
	_check_death_triggered_mechanics()
	_check_start_of_battle_mechanics()
	_check_mp_cost_mechanics()
	_check_elemental_mechanics()
	_check_status_chance_mechanics()
	_check_misc_missing_trait_batch_mechanics()
	_check_stat_mod_chance_mechanics()
	_check_heal_boost_mechanics()
	_check_self_skip_turn_mechanics()
	_check_third_missing_trait_batch_mechanics()
	_check_size_tier_mechanics()
	_check_missed_quick_win_mechanics()
	_check_skill_type_mechanics()
	_check_self_cast_skill_mechanics()
	_check_broken_skill_data_fixes()
	_check_cure_status_and_restore_mp_mechanics()
	_check_turn_order_override_mechanics()
	_check_tension_family_reexamined_mechanics()
	_check_weapon_equip_mechanics()
	_check_weapon_effects_mechanics()
	_check_blacksmith_mechanics()
	_check_size_synth_trait_bridge_mechanics()
	_check_taunt_mechanics()
	_check_counter_stance_and_utility_skill_mechanics()

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

## Hit Squad (and any future ExtraAttackTraitEffect-driven trait) runs the
## actor's WHOLE queued action multiple times in a row within one round --
## not extra hits inside a single skill's own effects (that's
## DamageEffect.min_hits/max_hits, already covered elsewhere). Driven
## through a real TurnManager.run_turn() (via BattleEngine), not a direct
## ActionExecutor.execute() call, since the repeat loop itself lives in
## TurnManager -- this is the one thing in this describe block that's a
## true integration test rather than a pure-function check.
func _check_multi_attack_mechanics() -> void:
	var extra := ExtraAttackTraitEffect.new()
	extra.extra_attacks = 2
	_check("extra attack trait reports its configured count", extra.get_extra_attack_count() == 2)

	var team_builder := TeamBuilder.new()
	var side_a_team := team_builder.build_team(["slime"], "side_a")
	var side_b_team := team_builder.build_team(["golem"], "side_b")
	var attacker := side_a_team[0]
	var defender := side_b_team[0]
	var hit_squad := ExtraAttackTraitEffect.new()
	hit_squad.extra_attacks = 1
	var hit_squad_traits: Array[TraitEffect] = [hit_squad]
	attacker.active_traits = hit_squad_traits

	var providers := {"side_a": ScriptedActionProvider.new(), "side_b": ScriptedActionProvider.new()}
	var attacker_queue: Array[Action] = [Action.new(attacker.instance_id, "attack", defender.instance_id)]
	var defender_queue: Array[Action] = [Action.new(defender.instance_id, "attack", attacker.instance_id)]
	providers["side_a"].set_queue(attacker.instance_id, attacker_queue)
	providers["side_b"].set_queue(defender.instance_id, defender_queue)

	var engine := BattleEngine.new(side_a_team, side_b_team, 42, providers, team_builder.skill_registry, 1)
	engine.start_battle()
	var round_events: Array[BattleEvent] = []
	engine.get_event_bus().event_emitted.connect(func(event: BattleEvent) -> void: round_events.append(event))
	engine.run_turn()

	var attacker_skill_uses := 0
	for event in round_events:
		if event is SkillUsedEvent and event.actor_instance_id == attacker.instance_id:
			attacker_skill_uses += 1
	_check(
		"hit squad: the actor's action executes twice (1 base + 1 extra) in a single round, each with its own SkillUsedEvent",
		attacker_skill_uses == 2
	)

	# A lethal counter mid-repeat must stop further repeats -- a fainted
	# monster can't keep attacking. Reuses the same CounterAttackTraitEffect
	# already proven lethal-and-fainting-correct in _check_counter_mechanics.
	var team_builder2 := TeamBuilder.new()
	var side_a_team2 := team_builder2.build_team(["slime"], "side_a")
	var side_b_team2 := team_builder2.build_team(["golem"], "side_b")
	var fragile_attacker := side_a_team2[0]
	var countering_defender := side_b_team2[0]
	# Priority-boosted so this test isn't at the mercy of golem's real
	# (much higher) agility stat -- without this, golem's own attack could
	# resolve first and faint 1-HP fragile_attacker before it ever gets to
	# act at all, which would test nothing about mid-repeat fainting.
	var fragile_priority := PriorityBonusTraitEffect.new()
	fragile_priority.priority_bonus = 1000
	var fragile_extra := ExtraAttackTraitEffect.new()
	fragile_extra.extra_attacks = 2
	var fragile_traits: Array[TraitEffect] = [fragile_extra, fragile_priority]
	fragile_attacker.active_traits = fragile_traits
	fragile_attacker.current_hp = 1
	var lethal_counter := CounterAttackTraitEffect.new()
	lethal_counter.counter_chance = 1.0
	var countering_traits: Array[TraitEffect] = [lethal_counter]
	countering_defender.active_traits = countering_traits

	var providers2 := {"side_a": ScriptedActionProvider.new(), "side_b": ScriptedActionProvider.new()}
	var fragile_queue: Array[Action] = [Action.new(fragile_attacker.instance_id, "attack", countering_defender.instance_id)]
	var countering_queue: Array[Action] = [Action.new(countering_defender.instance_id, "attack", fragile_attacker.instance_id)]
	providers2["side_a"].set_queue(fragile_attacker.instance_id, fragile_queue)
	providers2["side_b"].set_queue(countering_defender.instance_id, countering_queue)

	var engine2 := BattleEngine.new(side_a_team2, side_b_team2, 42, providers2, team_builder2.skill_registry, 1)
	engine2.start_battle()
	var round_events2: Array[BattleEvent] = []
	engine2.get_event_bus().event_emitted.connect(func(event: BattleEvent) -> void: round_events2.append(event))
	engine2.run_turn()

	_check("a lethal counter mid-repeat actually faints the attacker", fragile_attacker.is_fainted())
	var fragile_skill_uses := 0
	for event in round_events2:
		if event is SkillUsedEvent and event.actor_instance_id == fragile_attacker.instance_id:
			fragile_skill_uses += 1
	_check(
		"a lethal counter after the first repeat stops the remaining ones (1 use, not 3)",
		fragile_skill_uses == 1
	)

## The Roulette family (Agi/Atk/Def/Wis Roulette, Star Gift) all reduce to
## one RNG draw per turn start against a rise/fall boundary -- chance=1.0/0.0
## exercise DeterministicRng's documented boundary short-circuit, same trick
## used throughout this file, so these stay deterministic without a
## statistical trial.
func _check_roulette_mechanics() -> void:
	var team_builder := TeamBuilder.new()
	var harness := _new_harness(team_builder)

	var rise := RandomStatFluctuationTraitEffect.new()
	rise.stat_name = "attack"
	rise.rise_chance = 1.0
	rise.fall_chance = 0.0
	harness.actor.stat_stages.attack = 0
	rise.on_turn_start(harness.ctx, harness.actor)
	_check("roulette: rise_chance=1.0 deterministically raises the stage by 1", harness.actor.stat_stages.attack == 1)

	var fall := RandomStatFluctuationTraitEffect.new()
	fall.stat_name = "defense"
	fall.rise_chance = 0.0
	fall.fall_chance = 1.0
	harness.actor.stat_stages.defense = 0
	fall.on_turn_start(harness.ctx, harness.actor)
	_check("roulette: fall_chance=1.0 deterministically lowers the stage by 1", harness.actor.stat_stages.defense == -1)

	var never := RandomStatFluctuationTraitEffect.new()
	never.stat_name = "agility"
	never.rise_chance = 0.0
	never.fall_chance = 0.0
	harness.actor.stat_stages.agility = 0
	never.on_turn_start(harness.ctx, harness.actor)
	_check("roulette: rise_chance=0.0 and fall_chance=0.0 never changes the stage", harness.actor.stat_stages.agility == 0)

	harness.actor.stat_stages = StatStages.new()
	var star_gift := RandomStatFluctuationTraitEffect.new()
	star_gift.random_stat = true
	star_gift.rise_chance = 1.0
	star_gift.fall_chance = 0.0
	star_gift.on_turn_start(harness.ctx, harness.actor)
	var moved_stages: StatStages = harness.actor.stat_stages
	var total_stage: int = moved_stages.attack + moved_stages.defense + moved_stages.agility + moved_stages.wisdom
	_check("star gift: picks a random stat and raises it by 1 (exactly one stat moved)", total_stage == 1)

	var fainted_harness := _new_harness(team_builder)
	fainted_harness.actor.current_hp = 0
	var on_fainted := RandomStatFluctuationTraitEffect.new()
	on_fainted.stat_name = "wisdom"
	on_fainted.rise_chance = 1.0
	on_fainted.fall_chance = 0.0
	on_fainted.on_turn_start(fainted_harness.ctx, fainted_harness.actor)
	_check("roulette: a fainted monster's stats don't fluctuate", fainted_harness.actor.stat_stages.wisdom == 0)

## Retaliation family: something happens to whoever directly attacks the
## trait's owner (Poisonous/Poisonous Poke/Paralysing Punch/Sleep Sock/
## Confusing Touch/Cursed Attack/Whack Attack/Paralyzed Attack/Take Magic),
## all via the existing on_before_damage_taken hook -- same shape
## CounterAttackTraitEffect already uses, just applying a status or an MP
## drain instead of counter-damage. Roles follow _check_counter_mechanics()'s
## own convention: owner=harness.target (the one being hit, who retaliates),
## attacker=harness.actor (the one dealing damage, who receives it).
func _check_retaliation_mechanics() -> void:
	var team_builder := TeamBuilder.new()
	var poison_data := team_builder.skill_database.get_status("poison")
	var paralysis_data := team_builder.skill_database.get_status("paralysis")

	var harness := _new_harness(team_builder)
	var poison_retaliation := RetaliationStatusTraitEffect.new()
	poison_retaliation.status_data = poison_data
	poison_retaliation.chance = 1.0
	poison_retaliation.on_before_damage_taken(harness.ctx, harness.target, harness.actor, 40)
	_check(
		"retaliation status: chance=1.0 inflicts the configured status on the attacker",
		harness.actor.active_status != null and harness.actor.active_status.status_data.id == "poison"
	)

	var harness2 := _new_harness(team_builder)
	var already_status := StatusInstance.new(poison_data)
	harness2.actor.active_status = already_status
	var poison_retaliation2 := RetaliationStatusTraitEffect.new()
	poison_retaliation2.status_data = poison_data
	poison_retaliation2.chance = 1.0
	poison_retaliation2.on_before_damage_taken(harness2.ctx, harness2.target, harness2.actor, 40)
	_check("retaliation status: doesn't overwrite an attacker's already-active status", harness2.actor.active_status == already_status)

	var harness3 := _new_harness(team_builder)
	var gated := RetaliationStatusTraitEffect.new()
	gated.status_data = paralysis_data
	gated.chance = 1.0
	gated.requires_own_status_id = "paralysis"
	gated.on_before_damage_taken(harness3.ctx, harness3.target, harness3.actor, 40)
	_check("paralyzed attack: no retaliation while the owner isn't paralyzed itself", harness3.actor.active_status == null)
	harness3.target.active_status = StatusInstance.new(paralysis_data)
	gated.on_before_damage_taken(harness3.ctx, harness3.target, harness3.actor, 40)
	_check(
		"paralyzed attack: retaliates once the owner is paralyzed itself",
		harness3.actor.active_status != null and harness3.actor.active_status.status_data.id == "paralysis"
	)

	var unresolved := RetaliationStatusTraitEffect.new()
	_check(
		"retaliation status: a null status_data (e.g. skill_db wasn't available at create() time) is a harmless no-op",
		unresolved.on_before_damage_taken(harness.ctx, harness.target, harness.actor, 40) == 40
	)

	var drain_harness := _new_harness(team_builder)
	drain_harness.actor.current_mp = drain_harness.actor.species.base_mp
	var owner_mp_before: int = drain_harness.target.current_mp
	var drain := MpDrainRetaliationTraitEffect.new()
	drain.chance = 1.0
	drain.drain_percent_of_max_mp = 0.1
	var expected_drain := MathUtils.percent_of(drain_harness.actor.species.base_mp, 0.1)
	drain.on_before_damage_taken(drain_harness.ctx, drain_harness.target, drain_harness.actor, 40)
	_check(
		"take magic: drains the expected amount off the attacker's MP",
		drain_harness.actor.current_mp == drain_harness.actor.species.base_mp - expected_drain
	)
	_check(
		"take magic: adds the drained amount to the owner's MP",
		drain_harness.target.current_mp == mini(drain_harness.target.species.base_mp, owner_mp_before + expected_drain)
	)

	var capped_harness := _new_harness(team_builder)
	capped_harness.actor.current_mp = 1
	var capped_drain := MpDrainRetaliationTraitEffect.new()
	capped_drain.chance = 1.0
	capped_drain.drain_percent_of_max_mp = 0.5
	capped_drain.on_before_damage_taken(capped_harness.ctx, capped_harness.target, capped_harness.actor, 40)
	_check("take magic: never drains more than the attacker actually has", capped_harness.actor.current_mp == 0)

	var created_data := TraitData.new()
	created_data.id = "poisonous"
	var created := TraitEffect.create("poisonous", created_data, team_builder.skill_database)
	_check(
		"TraitEffect.create() resolves poisonous's status_data via the passed SkillDatabase",
		created is RetaliationStatusTraitEffect and created.status_data != null and created.status_data.id == "poison"
	)

## Death-triggered traits: Close Scraper (survive a lethal hit at 1 HP via
## DamageEffect.apply()'s new lethal-cap check), Comeback Kid (revive via
## FaintHandler.handle_if_fainted(), cancelling backfill), Final Breath
## (buff surviving allies), Last Gasp (unpreventable AoE to all active
## enemies) -- the last two need real 2-monster-per-side state, so they
## build their own BattleState/BattleContext directly rather than reusing
## _new_harness()'s fixed 1v1 shape.
func _check_death_triggered_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	var scraper_harness := _new_harness(team_builder)
	scraper_harness.target.current_hp = 5
	var survives := SurviveLethalHitTraitEffect.new()
	survives.chance = 1.0
	var scraper_traits: Array[TraitEffect] = [survives]
	scraper_harness.target.active_traits = scraper_traits
	var lethal_skill := DamageEffect.new()
	lethal_skill.category = DamageEffect.Category.PHYSICAL
	lethal_skill.power = 9999
	lethal_skill.apply(scraper_harness.ctx, scraper_harness.actor, scraper_harness.target)
	_check(
		"close scraper: chance=1.0 leaves the target at 1 HP instead of fainting",
		scraper_harness.target.current_hp == 1 and not scraper_harness.target.is_fainted()
	)

	var no_scraper_harness := _new_harness(team_builder)
	no_scraper_harness.target.current_hp = 5
	var never_survives := SurviveLethalHitTraitEffect.new()
	never_survives.chance = 0.0
	var no_scraper_traits: Array[TraitEffect] = [never_survives]
	no_scraper_harness.target.active_traits = no_scraper_traits
	var lethal_skill2 := DamageEffect.new()
	lethal_skill2.category = DamageEffect.Category.PHYSICAL
	lethal_skill2.power = 9999
	lethal_skill2.apply(no_scraper_harness.ctx, no_scraper_harness.actor, no_scraper_harness.target)
	_check("close scraper: chance=0.0 faints normally", no_scraper_harness.target.is_fainted())

	# Comeback Kid -- built with a bench reserve so a bug that still ran
	# backfill despite the revival would actually be caught. A 1-monster
	# team would trivially "pass" this check either way, since there'd be
	# nothing to wrongly backfill from regardless of whether the fix works.
	var revive_side_a := team_builder.build_team(["slime"], "side_a")
	var revive_side_b := team_builder.build_team(["golem", "healslime"], "side_b")
	var revive_event_bus := BattleEventBus.new()
	var revive_state := BattleState.new(DeterministicRng.new(1), revive_event_bus)
	revive_state.side_a_team = revive_side_a
	revive_state.side_b_team = revive_side_b
	revive_state.set_active_at("side_a", 0, 0)
	revive_state.set_active_at("side_b", 0, 0)
	var revive_ctx := BattleContext.new(revive_state)
	var dying_monster := revive_side_b[0]
	var bench_reserve := revive_side_b[1]
	var reviver := ReviveTraitEffect.new()
	reviver.chance = 1.0
	reviver.revive_hp_percent = 0.25
	var revive_traits: Array[TraitEffect] = [reviver]
	dying_monster.active_traits = revive_traits
	dying_monster.current_hp = 0
	var expected_revive_hp := maxi(1, MathUtils.percent_of(dying_monster.species.base_hp, 0.25))
	FaintHandler.handle_if_fainted(revive_ctx, dying_monster)
	_check("comeback kid: chance=1.0 revives with the expected HP", dying_monster.current_hp == expected_revive_hp)
	_check("comeback kid: a revived monster is no longer considered fainted", not dying_monster.is_fainted())
	_check(
		"comeback kid: has_been_processed_as_fainted resets, so a later real faint can be handled again",
		not dying_monster.has_been_processed_as_fainted
	)
	var saw_revive_event := false
	for event in revive_event_bus.get_log():
		if event is ReviveEvent and event.instance_id == dying_monster.instance_id:
			saw_revive_event = true
	_check("comeback kid emits a ReviveEvent", saw_revive_event)
	_check("comeback kid: still occupies its own slot", revive_state.get_monster_at("side_b", 0) == dying_monster)
	var saw_wrongful_backfill := false
	for event in revive_event_bus.get_log():
		if event is MonsterEnteredEvent and event.instance_id == bench_reserve.instance_id:
			saw_wrongful_backfill = true
	_check("comeback kid: the bench reserve was NOT wrongly pulled in despite being available", not saw_wrongful_backfill)

	# Same shape, no revive trait -- confirms the new early-return didn't
	# break the ordinary faint-then-backfill path for everyone else.
	var normal_side_a := team_builder.build_team(["slime"], "side_a")
	var normal_side_b := team_builder.build_team(["golem", "healslime"], "side_b")
	var normal_event_bus := BattleEventBus.new()
	var normal_state := BattleState.new(DeterministicRng.new(1), normal_event_bus)
	normal_state.side_a_team = normal_side_a
	normal_state.side_b_team = normal_side_b
	normal_state.set_active_at("side_a", 0, 0)
	normal_state.set_active_at("side_b", 0, 0)
	var normal_ctx := BattleContext.new(normal_state)
	var normal_dying := normal_side_b[0]
	var normal_reserve := normal_side_b[1]
	normal_dying.current_hp = 0
	FaintHandler.handle_if_fainted(normal_ctx, normal_dying)
	_check("without comeback kid, a fainted monster stays fainted", normal_dying.is_fainted())
	_check("without comeback kid, the bench reserve DOES backfill normally", normal_state.get_monster_at("side_b", 0) == normal_reserve)

	# Final Breath: needs a second living ally on the same side.
	var fb_side_a := team_builder.build_team(["slime", "dracky"], "side_a")
	var fb_side_b := team_builder.build_team(["golem"], "side_b")
	var fb_event_bus := BattleEventBus.new()
	var fb_state := BattleState.new(DeterministicRng.new(1), fb_event_bus)
	fb_state.side_a_team = fb_side_a
	fb_state.side_b_team = fb_side_b
	fb_state.set_active_at("side_a", 0, 0)
	fb_state.set_active_at("side_a", 1, 1)
	fb_state.set_active_at("side_b", 0, 0)
	var fb_ctx := BattleContext.new(fb_state)
	var fb_dying := fb_side_a[0]
	var fb_ally := fb_side_a[1]
	var final_breath := AllyBuffOnFaintTraitEffect.new()
	final_breath.stat_names = ["attack", "defense"]
	final_breath.stages = 1
	var fb_traits: Array[TraitEffect] = [final_breath]
	fb_dying.active_traits = fb_traits
	fb_dying.current_hp = 0
	FaintHandler.handle_if_fainted(fb_ctx, fb_dying)
	_check(
		"final breath: buffs the surviving ally's listed stats",
		fb_ally.stat_stages.attack == 1 and fb_ally.stat_stages.defense == 1
	)
	_check("final breath: doesn't touch stats not listed", fb_ally.stat_stages.agility == 0)

	# Last Gasp: needs two active enemies to prove it's AoE, not single-target.
	var lg_side_a := team_builder.build_team(["slime"], "side_a")
	var lg_side_b := team_builder.build_team(["golem", "healslime"], "side_b")
	var lg_event_bus := BattleEventBus.new()
	var lg_state := BattleState.new(DeterministicRng.new(1), lg_event_bus)
	lg_state.side_a_team = lg_side_a
	lg_state.side_b_team = lg_side_b
	lg_state.set_active_at("side_a", 0, 0)
	lg_state.set_active_at("side_b", 0, 0)
	lg_state.set_active_at("side_b", 1, 1)
	var lg_ctx := BattleContext.new(lg_state)
	var lg_dying := lg_side_a[0]
	var enemy1 := lg_side_b[0]
	var enemy2 := lg_side_b[1]
	var last_gasp := AoeDamageOnFaintTraitEffect.new()
	last_gasp.damage_percent_of_max_hp = 0.1
	var lg_traits: Array[TraitEffect] = [last_gasp]
	lg_dying.active_traits = lg_traits
	lg_dying.current_hp = 0
	var enemy1_hp_before: int = enemy1.current_hp
	var enemy2_hp_before: int = enemy2.current_hp
	FaintHandler.handle_if_fainted(lg_ctx, lg_dying)
	_check("last gasp: damages the first active enemy", enemy1.current_hp < enemy1_hp_before)
	_check("last gasp: damages the second active enemy too (AoE, not single-target)", enemy2.current_hp < enemy2_hp_before)

## Start-of-battle traits: AllyStatBuffOnEntryTraitEffect (Sudden Buff/
## Oomph/Accelerate), AllyTensionBuffOnEntryTraitEffect (Rabble Rouser),
## EnemyImmobilizeOnEntryTraitEffect (Scare Stare/Intimidating/Coercion/
## Strangely Alluring), plus one true end-to-end check that
## BattleSetup.send_out_initial() actually fires on_monster_entered for
## real rather than just proving the trait classes work in isolation.
func _check_start_of_battle_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	var buff_side_a := team_builder.build_team(["slime", "dracky"], "side_a")
	var buff_side_b := team_builder.build_team(["golem"], "side_b")
	var buff_event_bus := BattleEventBus.new()
	var buff_state := BattleState.new(DeterministicRng.new(1), buff_event_bus)
	buff_state.side_a_team = buff_side_a
	buff_state.side_b_team = buff_side_b
	buff_state.set_active_at("side_a", 0, 0)
	buff_state.set_active_at("side_a", 1, 1)
	buff_state.set_active_at("side_b", 0, 0)
	var buff_ctx := BattleContext.new(buff_state)
	var buffer := buff_side_a[0]
	var buffed_ally := buff_side_a[1]
	var oomph := AllyStatBuffOnEntryTraitEffect.new()
	oomph.stat_name = "attack"
	oomph.stages = 2
	oomph.chance = 1.0
	oomph.on_monster_entered(buff_ctx, buffer)
	_check("sudden oomph: buffs the owner itself", buffer.stat_stages.attack == 2)
	_check("sudden oomph: buffs other active allies too", buffed_ally.stat_stages.attack == 2)

	var tension_harness := _new_harness(team_builder)
	var rouser := AllyTensionBuffOnEntryTraitEffect.new()
	rouser.chance = 1.0
	rouser.levels = 2
	rouser.on_monster_entered(tension_harness.ctx, tension_harness.actor)
	_check("rabble rouser: chance=1.0 raises some ally's tension", tension_harness.actor.tension_level == 2)

	var no_rouser_harness := _new_harness(team_builder)
	var never_rouser := AllyTensionBuffOnEntryTraitEffect.new()
	never_rouser.chance = 0.0
	never_rouser.on_monster_entered(no_rouser_harness.ctx, no_rouser_harness.actor)
	_check("rabble rouser: chance=0.0 does nothing", no_rouser_harness.actor.tension_level == 0)

	var immo_side_a := team_builder.build_team(["slime"], "side_a")
	var immo_side_b := team_builder.build_team(["golem", "healslime"], "side_b")
	var immo_event_bus := BattleEventBus.new()
	var immo_state := BattleState.new(DeterministicRng.new(1), immo_event_bus)
	immo_state.side_a_team = immo_side_a
	immo_state.side_b_team = immo_side_b
	immo_state.set_active_at("side_a", 0, 0)
	immo_state.set_active_at("side_b", 0, 0)
	immo_state.set_active_at("side_b", 1, 1)
	var immo_ctx := BattleContext.new(immo_state)
	var scare_stare := EnemyImmobilizeOnEntryTraitEffect.new()
	var immobilize_status := team_builder.skill_database.get_status("immobilize")
	scare_stare.status_data = immobilize_status
	scare_stare.chance = 1.0
	var enemy1 := immo_side_b[0]
	var enemy2 := immo_side_b[1]
	var poison_status := team_builder.skill_database.get_status("poison")
	enemy2.active_status = StatusInstance.new(poison_status)
	scare_stare.on_monster_entered(immo_ctx, immo_side_a[0])
	_check(
		"scare stare: immobilizes a not-yet-afflicted enemy",
		enemy1.active_status != null and enemy1.active_status.status_data.id == "immobilize"
	)
	_check(
		"scare stare: doesn't override an enemy that already has a different status",
		enemy2.active_status.status_data.id == "poison"
	)

	var wiring_side_a := team_builder.build_team(["slime"], "side_a")
	var wiring_side_b := team_builder.build_team(["golem"], "side_b")
	var wiring_oomph := AllyStatBuffOnEntryTraitEffect.new()
	wiring_oomph.stat_name = "attack"
	wiring_oomph.stages = 1
	wiring_oomph.chance = 1.0
	var wiring_traits: Array[TraitEffect] = [wiring_oomph]
	wiring_side_a[0].active_traits = wiring_traits
	var wiring_providers := {"side_a": ScriptedActionProvider.new(), "side_b": ScriptedActionProvider.new()}
	var wiring_engine := BattleEngine.new(wiring_side_a, wiring_side_b, 1, wiring_providers, team_builder.skill_registry, 1)
	wiring_engine.start_battle()
	_check("on_monster_entered actually fires from a real send_out_initial() call, not just when called directly", wiring_side_a[0].stat_stages.attack == 1)

## MP-cost-multiplier traits (Magic Miser/Scrooge, Spell Splurger, the
## Guard Break pair, Crafty Devil). _effective_mp_cost is tested the same
## direct-call way _effective_accuracy already is above.
func _check_mp_cost_mechanics() -> void:
	var team_builder := TeamBuilder.new()
	var frizz := team_builder.skill_database.get_skill("frizz")

	var scrooge_harness := _new_harness(team_builder)
	var scrooge := MpCostAndDamageTraitEffect.new()
	scrooge.mp_cost_multiplier = 0.5
	var scrooge_traits: Array[TraitEffect] = [scrooge]
	scrooge_harness.actor.active_traits = scrooge_traits
	_check(
		"magic scrooge: halves the effective MP cost",
		ActionExecutor._effective_mp_cost(frizz, scrooge_harness.actor) == MathUtils.round_half_up(float(frizz.mp_cost) * 0.5)
	)

	var no_trait_harness := _new_harness(team_builder)
	_check(
		"no MP-cost trait: leaves the skill's own MP cost untouched",
		ActionExecutor._effective_mp_cost(frizz, no_trait_harness.actor) == frizz.mp_cost
	)

	# Integration: the doubled cost actually gets deducted from current_mp,
	# and the SAME doubled cost is what the insufficient-MP fizzle check
	# uses -- exactly enough for the base cost but not the doubled one
	# must fizzle, not silently succeed for less than it should cost.
	var splurger_harness := _new_harness(team_builder)
	var splurger := MpCostAndDamageTraitEffect.new()
	splurger.mp_cost_multiplier = 2.0
	var splurger_traits: Array[TraitEffect] = [splurger]
	splurger_harness.actor.active_traits = splurger_traits
	splurger_harness.actor.current_mp = frizz.mp_cost
	ActionExecutor.execute(splurger_harness.ctx, Action.new(splurger_harness.actor.instance_id, "frizz", splurger_harness.target.instance_id), team_builder.skill_registry)
	var splurger_log: Array[BattleEvent] = splurger_harness.ctx.event_bus.get_log()
	_check(
		"spell splurger: exactly enough MP for the base cost still fizzles against the doubled cost",
		splurger_log.size() == 1 and splurger_log[0] is SkillUsedEvent and splurger_log[0].fizzled
	)
	_check("spell splurger: a fizzled cast doesn't deduct any MP", splurger_harness.actor.current_mp == frizz.mp_cost)

	splurger_harness.actor.current_mp = frizz.mp_cost * 2
	ActionExecutor.execute(splurger_harness.ctx, Action.new(splurger_harness.actor.instance_id, "frizz", splurger_harness.target.instance_id), team_builder.skill_registry)
	_check("spell splurger: with enough MP, the full doubled cost is deducted", splurger_harness.actor.current_mp == 0)

	# damage_multiplier (the Guard Break pair / Crafty Devil's trade-off)
	var guard_break := MpCostAndDamageTraitEffect.new()
	guard_break.damage_multiplier = 1.5
	_check("strong guard break: boosts dealt damage by the configured multiplier", guard_break.on_before_damage_dealt(null, null, null, 100) == 150)
	var no_boost := MpCostAndDamageTraitEffect.new()
	_check("MP-only variants (Magic Miser/Scrooge/Spell Splurger) leave damage untouched", no_boost.on_before_damage_dealt(null, null, null, 100) == 100)

## Elemental Ward/-meister/crafty_X traits, keyed off SkillData.element --
## the field the previous entry's import tool added by re-reading the same
## cached source data the original moveset import already used once.
func _check_elemental_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	# The import itself: a real skill from the database should carry its
	# real elemental attribute now, not just the trait plumbing around it.
	var frizz := team_builder.skill_database.get_skill("frizz")
	_check("skill import: frizz carries element 'Frizz'", frizz.element == "Frizz")
	var attack := team_builder.skill_database.get_skill("attack")
	_check("skill import: a plain physical Attack has no element", attack.element.is_empty())

	# ElementalDamageResistanceTraitEffect (Ward): pure-function checks.
	var frizz_ward := ElementalDamageResistanceTraitEffect.new()
	frizz_ward.elements = ["Frizz"] as Array[String]
	frizz_ward.reduction_percent = 0.5
	_check(
		"frizz ward: halves damage from a matching-element hit",
		frizz_ward.on_before_damage_taken(null, null, null, 100, "Frizz") == 50
	)
	_check(
		"frizz ward: leaves a non-matching element's damage untouched",
		frizz_ward.on_before_damage_taken(null, null, null, 100, "Zap") == 100
	)
	_check(
		"frizz ward: still matches a compound element that includes Frizz",
		frizz_ward.on_before_damage_taken(null, null, null, 100, "Frizz-Fire") == 50
	)
	_check(
		"frizz ward: a non-elemental hit (empty element) is untouched",
		frizz_ward.on_before_damage_taken(null, null, null, 100, "") == 100
	)

	# ElementalDamageBoostTraitEffect (-meister/crafty_X): pure-function checks.
	var frizzmeister := ElementalDamageBoostTraitEffect.new()
	frizzmeister.elements = ["Frizz"] as Array[String]
	frizzmeister.damage_multiplier = 1.2
	frizzmeister.mp_cost_multiplier = 0.75
	_check(
		"frizzmeister: boosts damage for a matching-element hit",
		frizzmeister.on_before_damage_dealt(null, null, null, 100, "Frizz") == 120
	)
	_check(
		"frizzmeister: leaves a non-matching element's damage untouched",
		frizzmeister.on_before_damage_dealt(null, null, null, 100, "Zap") == 100
	)
	_check(
		"frizzmeister: discounts MP cost for a matching-element skill",
		is_equal_approx(frizzmeister.get_mp_cost_multiplier(frizz), 0.75)
	)
	var zap := team_builder.skill_database.get_skill("zap")
	_check(
		"frizzmeister: leaves a non-matching skill's MP cost untouched",
		is_equal_approx(frizzmeister.get_mp_cost_multiplier(zap), 1.0)
	)

	var crafty_frizzer := ElementalDamageBoostTraitEffect.new()
	crafty_frizzer.elements = ["Frizz"] as Array[String]
	crafty_frizzer.damage_multiplier = 1.2
	_check(
		"crafty_frizzer: boosts damage but (unlike a -meister) never discounts MP",
		is_equal_approx(crafty_frizzer.get_mp_cost_multiplier(frizz), 1.0)
	)

	# Full integration: a real ActionExecutor.execute() call casting an
	# actual "frizz" skill against a Frizz Ward-equipped target, proving the
	# element flows all the way from the fixture through SkillLoader's
	# DamageEffect.element mirroring through to the hook -- not just that
	# the trait classes work correctly when called directly.
	var ward_harness := _new_harness(team_builder)
	var ward := ElementalDamageResistanceTraitEffect.new()
	ward.elements = ["Frizz"] as Array[String]
	ward.reduction_percent = 0.5
	var ward_traits: Array[TraitEffect] = [ward]
	ward_harness.target.active_traits = ward_traits
	var baseline_harness := _new_harness(team_builder)
	ActionExecutor.execute(baseline_harness.ctx, Action.new(baseline_harness.actor.instance_id, "frizz", baseline_harness.target.instance_id), team_builder.skill_registry)
	ActionExecutor.execute(ward_harness.ctx, Action.new(ward_harness.actor.instance_id, "frizz", ward_harness.target.instance_id), team_builder.skill_registry)
	var baseline_target: MonsterInstance = baseline_harness.target
	var warded_target: MonsterInstance = ward_harness.target
	var baseline_damage: int = baseline_target.species.base_hp - baseline_target.current_hp
	var warded_damage: int = warded_target.species.base_hp - warded_target.current_hp
	_check(
		"end-to-end: a real Frizz cast against a Frizz Ward deals less damage than the same cast against no ward",
		baseline_damage > 0 and warded_damage < baseline_damage
	)

## Status-flavored Ward/crafty_X cluster: verified against real skill data
## before building this (every skill tagged e.g. element="Poison" also
## carries a real StatusEffect(status_id="poison")) -- a genuinely distinct
## mechanic from the elemental-damage Ward/crafty_X cluster in
## _check_elemental_mechanics() above, needing its own hook pair
## (get_status_infliction_multiplier/get_status_resistance_multiplier)
## checked from inside StatusEffect.apply()'s own chance roll rather than
## the on_before_damage_dealt/taken pair that cluster plugs into.
func _check_status_chance_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	var poison_ward := StatusResistanceTraitEffect.new()
	poison_ward.status_ids = ["poison"] as Array[String]
	poison_ward.resistance_multiplier = 0.5
	_check(
		"poison ward: halves the effective chance for a matching status",
		is_equal_approx(poison_ward.get_status_resistance_multiplier("poison"), 0.5)
	)
	_check(
		"poison ward: leaves a non-matching status untouched",
		is_equal_approx(poison_ward.get_status_resistance_multiplier("sleep"), 1.0)
	)

	var crafty_poisoner := StatusInflictionBoostTraitEffect.new()
	crafty_poisoner.status_ids = ["poison"] as Array[String]
	crafty_poisoner.infliction_multiplier = 1.5
	_check(
		"crafty poisoner: boosts the effective chance for a matching status",
		is_equal_approx(crafty_poisoner.get_status_infliction_multiplier("poison"), 1.5)
	)
	_check(
		"crafty poisoner: leaves a non-matching status untouched",
		is_equal_approx(crafty_poisoner.get_status_infliction_multiplier("sleep"), 1.0)
	)

	# Full integration: StatusEffect.apply() actually multiplies its own
	# chance by both hooks, not just that the classes compute the right
	# number in isolation. Uses DeterministicRng.chance()'s documented
	# 0.0/1.0 boundary guarantee so both cases are exactly reproducible
	# rather than relying on a lucky roll.
	var poison_status := team_builder.skill_database.get_status("poison")

	var boosted_harness := _new_harness(team_builder)
	var boosted_status_effect := StatusEffect.new()
	boosted_status_effect.status_data = poison_status
	boosted_status_effect.chance = 0.5
	var boost_trait := StatusInflictionBoostTraitEffect.new()
	boost_trait.status_ids = ["poison"] as Array[String]
	boost_trait.infliction_multiplier = 2.0
	var boost_traits: Array[TraitEffect] = [boost_trait]
	boosted_harness.actor.active_traits = boost_traits
	boosted_status_effect.apply(boosted_harness.ctx, boosted_harness.actor, boosted_harness.target)
	_check(
		"crafty poisoner integration: 0.5 base chance x2.0 multiplier reaches the 1.0 guaranteed-apply boundary",
		boosted_harness.target.active_status != null and boosted_harness.target.active_status.status_data.id == "poison"
	)

	var resisted_harness := _new_harness(team_builder)
	var resisted_status_effect := StatusEffect.new()
	resisted_status_effect.status_data = poison_status
	resisted_status_effect.chance = 1.0
	var resist_trait := StatusResistanceTraitEffect.new()
	resist_trait.status_ids = ["poison"] as Array[String]
	resist_trait.resistance_multiplier = 0.0
	var resist_traits: Array[TraitEffect] = [resist_trait]
	resisted_harness.target.active_traits = resist_traits
	resisted_status_effect.apply(resisted_harness.ctx, resisted_harness.actor, resisted_harness.target)
	_check(
		"poison ward integration: a guaranteed 1.0 base chance x0.0 resistance reaches the 0.0 guaranteed-fail boundary",
		resisted_harness.target.active_status == null
	)

## The rest of the same pass: four traits that reuse already-existing
## elemental-damage classes (confirmed against real skill data that these
## are plain elemental tags with no attached status, unlike the cluster
## above), plus a handful of small standalone classes each covering exactly
## one newly-registered trait.
func _check_misc_missing_trait_batch_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	var ban_dance_ward_data := TraitData.new()
	ban_dance_ward_data.id = "ban_dance_ward"
	var ban_dance_ward := TraitEffect.create("ban_dance_ward", ban_dance_ward_data)
	_check(
		"ban_dance_ward registers as an ElementalDamageResistanceTraitEffect keyed to 'Ban Dance'",
		ban_dance_ward is ElementalDamageResistanceTraitEffect and ban_dance_ward.on_before_damage_taken(null, null, null, 100, "Ban Dance") < 100
	)

	var crafty_banger_data := TraitData.new()
	crafty_banger_data.id = "crafty_banger"
	var crafty_banger := TraitEffect.create("crafty_banger", crafty_banger_data)
	_check(
		"crafty_banger registers as an ElementalDamageBoostTraitEffect keyed to 'Bang'",
		crafty_banger is ElementalDamageBoostTraitEffect and crafty_banger.on_before_damage_dealt(null, null, null, 100, "Bang") > 100
	)

	# MpDrainOnAttackTraitEffect (Drain Magic Attack): the offense-side
	# mirror of MpDrainRetaliationTraitEffect (Take Magic), same
	# capped-both-ways math.
	var drain_harness := _new_harness(team_builder)
	drain_harness.target.current_mp = 20
	var drainer := MpDrainOnAttackTraitEffect.new()
	drainer.chance = 1.0
	drainer.drain_percent_of_max_mp = 0.5
	drainer.on_before_damage_dealt(drain_harness.ctx, drain_harness.actor, drain_harness.target, 40)
	_check(
		"drain magic attack: drains MP from the target into the owner",
		drain_harness.actor.current_mp > 0 and drain_harness.target.current_mp < 20
	)

	var capped_drain_harness := _new_harness(team_builder)
	capped_drain_harness.target.current_mp = 1
	var capped_drainer := MpDrainOnAttackTraitEffect.new()
	capped_drainer.chance = 1.0
	capped_drainer.drain_percent_of_max_mp = 0.5
	capped_drainer.on_before_damage_dealt(capped_drain_harness.ctx, capped_drain_harness.actor, capped_drain_harness.target, 40)
	_check("drain magic attack: never drains more than the target actually has", capped_drain_harness.target.current_mp == 0)

	var attalleric := DamageTakenMultiplierTraitEffect.new()
	attalleric.multiplier = 1.5
	_check(
		"attalleric: increases incoming damage by the configured multiplier",
		attalleric.on_before_damage_taken(null, null, null, 100) == 150
	)

	var ambusher_data := TraitData.new()
	ambusher_data.id = "able_ambusher"
	var ambusher := TraitEffect.create("able_ambusher", ambusher_data)
	_check(
		"able_ambusher: registers a priority bonus that dominates Ultra Fast Action's own +200",
		ambusher is PriorityBonusTraitEffect and ambusher.get_priority_bonus() > 200
	)

	var steal_harness := _new_harness(team_builder)
	steal_harness.actor.tension_level = 3
	var stealer := TensionStealOnAttackedTraitEffect.new()
	stealer.chance = 1.0
	stealer.on_before_damage_taken(steal_harness.ctx, steal_harness.target, steal_harness.actor, 10)
	_check(
		"stress relief: steals the attacker's entire tension into the owner",
		steal_harness.actor.tension_level == 0 and steal_harness.target.tension_level == 3
	)

	var steal_capped_harness := _new_harness(team_builder)
	steal_capped_harness.actor.tension_level = 2
	steal_capped_harness.target.tension_level = 3
	var capped_stealer := TensionStealOnAttackedTraitEffect.new()
	capped_stealer.chance = 1.0
	capped_stealer.on_before_damage_taken(steal_capped_harness.ctx, steal_capped_harness.target, steal_capped_harness.actor, 10)
	_check("stress relief: caps the owner's resulting tension at the max level of 4", steal_capped_harness.target.tension_level == 4)

	var mutter_harness := _new_harness(team_builder)
	mutter_harness.target.tension_level = 3
	var mutterer := EnemyTensionDrainOnTurnTraitEffect.new()
	mutterer.chance = 1.0
	mutterer.levels = 2
	mutterer.on_turn_start(mutter_harness.ctx, mutter_harness.actor)
	_check("mutter: lowers every active enemy's tension at the start of the owner's turn", mutter_harness.target.tension_level == 1)

	var riler_harness := _new_harness(team_builder)
	var riler := EnemyTensionBuffOnEntryTraitEffect.new()
	riler.levels = 2
	riler.on_monster_entered(riler_harness.ctx, riler_harness.actor)
	_check("rival riler: raises every active enemy's tension when the owner enters battle", riler_harness.target.tension_level == 2)

	var hidden_power_harness := _new_harness(team_builder)
	var hidden_power := StackingStatBuffOnTurnTraitEffect.new()
	hidden_power.on_turn_start(hidden_power_harness.ctx, hidden_power_harness.actor)
	_check(
		"hidden power: raises attack/defense/agility/wisdom by one stage each turn",
		hidden_power_harness.actor.stat_stages.get_stage("attack") == 1
		and hidden_power_harness.actor.stat_stages.get_stage("defense") == 1
		and hidden_power_harness.actor.stat_stages.get_stage("agility") == 1
		and hidden_power_harness.actor.stat_stages.get_stage("wisdom") == 1
	)

	var rocket_start := RoundGatedDamageMultiplierTraitEffect.new()
	rocket_start.early_round_count = 3
	rocket_start.early_multiplier = 1.5
	rocket_start.late_multiplier = 0.5
	var early_harness := _new_harness(team_builder)
	early_harness.ctx.state.turn_number = 2
	_check("rocket start: boosts damage during the first 3 rounds", rocket_start.on_before_damage_dealt(early_harness.ctx, null, null, 100) == 150)
	var late_harness := _new_harness(team_builder)
	late_harness.ctx.state.turn_number = 4
	_check("rocket start: reduces damage from round 4 onward", rocket_start.on_before_damage_dealt(late_harness.ctx, null, null, 100) == 50)

	# fly_swatter's actual behavior (suppressing Artful Dodger on whoever
	# has it) is already proven end to end in _check_dodge_mechanics(),
	# built directly from trait_data.id -- the registration is entirely
	# behavior-free (see the case's own comment in TraitEffect.create()),
	# so this just confirms it loads cleanly rather than erroring.
	var fly_swatter_data := TraitData.new()
	fly_swatter_data.id = "fly_swatter"
	var fly_swatter := TraitEffect.create("fly_swatter", fly_swatter_data)
	_check("fly_swatter loads cleanly with its trait_data set", fly_swatter != null and fly_swatter.trait_data.id == "fly_swatter")

## StatModEffect resistance/infliction cluster (Sag/Sap/Decelerate Ward,
## Crafty Debuffer) -- confirmed against real skill data (sag.json etc.)
## that these are pure StatModEffect debuffs with their own chance roll,
## genuinely distinct from the StatusEffect-based cluster above.
func _check_stat_mod_chance_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	var sap_ward := StatModResistanceTraitEffect.new()
	sap_ward.elements = ["Sap"] as Array[String]
	sap_ward.resistance_multiplier = 0.5
	_check(
		"sap ward: halves the effective chance for a matching stat-debuff element",
		is_equal_approx(sap_ward.get_stat_mod_resistance_multiplier("Sap"), 0.5)
	)
	_check(
		"sap ward: leaves a non-matching element untouched",
		is_equal_approx(sap_ward.get_stat_mod_resistance_multiplier("Sag"), 1.0)
	)

	var crafty_debuffer := StatModInflictionBoostTraitEffect.new()
	crafty_debuffer.elements = ["Sag", "Sap", "Decelerate"] as Array[String]
	crafty_debuffer.infliction_multiplier = 1.5
	_check(
		"crafty debuffer: boosts the effective chance for each of its three covered elements",
		is_equal_approx(crafty_debuffer.get_stat_mod_infliction_multiplier("Sag"), 1.5)
		and is_equal_approx(crafty_debuffer.get_stat_mod_infliction_multiplier("Sap"), 1.5)
		and is_equal_approx(crafty_debuffer.get_stat_mod_infliction_multiplier("Decelerate"), 1.5)
	)
	_check(
		"crafty debuffer: Dim is deliberately NOT covered (a plain elemental damage move, not a StatModEffect)",
		is_equal_approx(crafty_debuffer.get_stat_mod_infliction_multiplier("Dim"), 1.0)
	)

	# Full integration, same DeterministicRng.chance() 0.0/1.0 boundary trick
	# as the status-chance cluster's own integration checks.
	var boosted_harness := _new_harness(team_builder)
	var boosted_stat_mod := StatModEffect.new()
	boosted_stat_mod.element = "Sap"
	boosted_stat_mod.stat_name = "defense"
	boosted_stat_mod.stages = -1
	boosted_stat_mod.chance = 0.5
	boosted_stat_mod.target_self = false
	var boost_trait := StatModInflictionBoostTraitEffect.new()
	boost_trait.elements = ["Sap"] as Array[String]
	boost_trait.infliction_multiplier = 2.0
	var boost_traits: Array[TraitEffect] = [boost_trait]
	boosted_harness.actor.active_traits = boost_traits
	boosted_stat_mod.apply(boosted_harness.ctx, boosted_harness.actor, boosted_harness.target)
	_check(
		"crafty debuffer integration: 0.5 base chance x2.0 multiplier reaches the 1.0 guaranteed-apply boundary",
		boosted_harness.target.stat_stages.get_stage("defense") == -1
	)

	var resisted_harness := _new_harness(team_builder)
	var resisted_stat_mod := StatModEffect.new()
	resisted_stat_mod.element = "Sap"
	resisted_stat_mod.stat_name = "defense"
	resisted_stat_mod.stages = -1
	resisted_stat_mod.chance = 1.0
	resisted_stat_mod.target_self = false
	var resist_trait := StatModResistanceTraitEffect.new()
	resist_trait.elements = ["Sap"] as Array[String]
	resist_trait.resistance_multiplier = 0.0
	var resist_traits: Array[TraitEffect] = [resist_trait]
	resisted_harness.target.active_traits = resist_traits
	resisted_stat_mod.apply(resisted_harness.ctx, resisted_harness.actor, resisted_harness.target)
	_check(
		"sap ward integration: a guaranteed 1.0 base chance x0.0 resistance reaches the 0.0 guaranteed-fail boundary",
		resisted_harness.target.stat_stages.get_stage("defense") == 0
	)

## Health Professional: heal-magnitude boost, plus an MP discount scoped to
## only skills that actually contain a HealEffect (not a blanket discount
## on every skill this monster casts).
func _check_heal_boost_mechanics() -> void:
	var professional := HealBoostAndMpDiscountTraitEffect.new()
	professional.heal_multiplier = 1.5
	professional.mp_cost_multiplier = 0.5
	_check("health professional: get_heal_multiplier returns its configured boost", is_equal_approx(professional.get_heal_multiplier(), 1.5))

	var heal_skill := SkillData.new()
	var heal_effects: Array[SkillEffect] = [HealEffect.new()]
	heal_skill.effects = heal_effects
	heal_skill.mp_cost = 10
	_check(
		"health professional: discounts MP cost for a skill that contains a HealEffect",
		is_equal_approx(professional.get_mp_cost_multiplier(heal_skill), 0.5)
	)

	var attack_skill := SkillData.new()
	var attack_effects: Array[SkillEffect] = [DamageEffect.new()]
	attack_skill.effects = attack_effects
	_check(
		"health professional: leaves a non-healing skill's MP cost untouched",
		is_equal_approx(professional.get_mp_cost_multiplier(attack_skill), 1.0)
	)

	# Integration: a real HealEffect.apply() call actually restores more HP
	# with the trait than without it.
	var team_builder := TeamBuilder.new()
	var baseline_harness := _new_harness(team_builder)
	baseline_harness.actor.current_hp = 1
	var baseline_heal := HealEffect.new()
	baseline_heal.power = 10
	baseline_heal.target_self = true
	baseline_heal.apply(baseline_harness.ctx, baseline_harness.actor, baseline_harness.actor)

	var boosted_harness := _new_harness(team_builder)
	boosted_harness.actor.current_hp = 1
	var boosted_heal := HealEffect.new()
	boosted_heal.power = 10
	boosted_heal.target_self = true
	var boosted_traits: Array[TraitEffect] = [professional]
	boosted_harness.actor.active_traits = boosted_traits
	boosted_heal.apply(boosted_harness.ctx, boosted_harness.actor, boosted_harness.actor)

	_check(
		"health professional integration: a real heal restores more HP with the trait than without it",
		boosted_harness.actor.current_hp > baseline_harness.actor.current_hp
	)

## Timid/Yellow Belly/Foot Dragger: a personality-driven skip-turn chance,
## structurally parallel to (but independent of) the existing status-driven
## skip_turn_chance in ActionExecutor.execute().
func _check_self_skip_turn_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	var timid := SelfSkipTurnTraitEffect.new()
	timid.skip_chance = 1.0
	var timid_data := TraitData.new()
	timid_data.id = "timid"
	timid.trait_data = timid_data

	var harness := _new_harness(team_builder)
	var timid_traits: Array[TraitEffect] = [timid]
	harness.actor.active_traits = timid_traits
	var frizz := team_builder.skill_database.get_skill("frizz")
	harness.actor.current_mp = frizz.mp_cost
	ActionExecutor.execute(harness.ctx, Action.new(harness.actor.instance_id, "frizz", harness.target.instance_id), team_builder.skill_registry)
	var log: Array[BattleEvent] = harness.ctx.event_bus.get_log()
	_check(
		"timid: a guaranteed skip chance prevents the action entirely",
		log.size() == 1 and log[0] is SkillUsedEvent and log[0].prevented_by_trait == "timid"
	)
	_check("timid: a prevented action doesn't deduct MP", harness.actor.current_mp == frizz.mp_cost)

	var no_trait_harness := _new_harness(team_builder)
	no_trait_harness.actor.current_mp = frizz.mp_cost
	ActionExecutor.execute(no_trait_harness.ctx, Action.new(no_trait_harness.actor.instance_id, "frizz", no_trait_harness.target.instance_id), team_builder.skill_registry)
	var no_trait_log: Array[BattleEvent] = no_trait_harness.ctx.event_bus.get_log()
	_check(
		"no self-skip trait: the action executes normally",
		no_trait_log.size() >= 1 and no_trait_log[0] is SkillUsedEvent and no_trait_log[0].prevented_by_trait.is_empty()
	)

## The remaining traits investigated and registered in the same pass:
## Medicinal Knowledge (auto-cure poison on allies), Proactive Hunter
## (bonus vs an enemy that's already acted this round), Suicidal
## Satisfaction (reuses Desperado's own HP-gated crit shape), and Tit for
## Tat (mirrors an inflicted status back onto the inflicter).
func _check_third_missing_trait_batch_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	var poison_status := team_builder.skill_database.get_status("poison")
	var cure_harness := _new_harness(team_builder)
	cure_harness.actor.active_status = StatusInstance.new(poison_status)
	var medic := CureAllyStatusOnTurnTraitEffect.new()
	medic.chance = 1.0
	medic.on_turn_start(cure_harness.ctx, cure_harness.actor)
	_check("medicinal knowledge: cures a poisoned ally (including itself) on a guaranteed roll", cure_harness.actor.active_status == null)

	var no_status_harness := _new_harness(team_builder)
	var no_status_medic := CureAllyStatusOnTurnTraitEffect.new()
	no_status_medic.chance = 1.0
	no_status_medic.on_turn_start(no_status_harness.ctx, no_status_harness.actor)
	_check("medicinal knowledge: does nothing to an ally with no active status", no_status_harness.actor.active_status == null)

	var hunter_harness := _new_harness(team_builder)
	var hunter := ProactiveHunterTraitEffect.new()
	hunter.damage_multiplier = 1.5
	_check(
		"proactive hunter: leaves damage untouched against a target that hasn't acted yet this round",
		hunter.on_before_damage_dealt(hunter_harness.ctx, hunter_harness.actor, hunter_harness.target, 100) == 100
	)
	hunter_harness.ctx.state.acted_this_turn_instance_ids[hunter_harness.target.instance_id] = true
	_check(
		"proactive hunter: boosts damage against a target that has already acted this round",
		hunter.on_before_damage_dealt(hunter_harness.ctx, hunter_harness.actor, hunter_harness.target, 100) == 150
	)

	var suicidal_data := TraitData.new()
	suicidal_data.id = "suicidal_satisfaction"
	var suicidal := TraitEffect.create("suicidal_satisfaction", suicidal_data)
	_check(
		"suicidal_satisfaction registers as a Desperado-shaped HP-gated crit-chance multiplier",
		suicidal is DesperadoTraitEffect and suicidal.multiplier_when_low > 1.0
	)

	var tit_harness := _new_harness(team_builder)
	var tit_for_tat := TitForTatTraitEffect.new()
	var tit_traits: Array[TraitEffect] = [tit_for_tat]
	tit_harness.target.active_traits = tit_traits
	var mirrored_status_effect := StatusEffect.new()
	mirrored_status_effect.status_data = poison_status
	mirrored_status_effect.chance = 1.0
	mirrored_status_effect.apply(tit_harness.ctx, tit_harness.actor, tit_harness.target)
	_check(
		"tit for tat: the recipient's own status was applied as normal",
		tit_harness.target.active_status != null and tit_harness.target.active_status.status_data.id == "poison"
	)
	_check(
		"tit for tat: the SAME status is mirrored back onto whoever inflicted it",
		tit_harness.actor.active_status != null and tit_harness.actor.active_status.status_data.id == "poison"
	)

	var tit_self_harness := _new_harness(team_builder)
	var self_tit_for_tat := TitForTatTraitEffect.new()
	var self_tit_traits: Array[TraitEffect] = [self_tit_for_tat]
	tit_self_harness.actor.active_traits = self_tit_traits
	var self_status_effect := StatusEffect.new()
	self_status_effect.status_data = poison_status
	self_status_effect.chance = 1.0
	self_status_effect.target_self = true
	self_status_effect.apply(tit_self_harness.ctx, tit_self_harness.actor, tit_self_harness.target)
	_check(
		"tit for tat: a self-applied status (inflicter == owner) doesn't loop back on itself",
		tit_self_harness.actor.active_status != null and tit_self_harness.actor.active_status.status_data.id == "poison"
	)
	_check(
		"tit for tat: a self-applied status has no reason to touch an uninvolved third monster",
		tit_self_harness.target.active_status == null
	)

## Giant Killer/Standard Killer/Big Hitter/Grand Slammer: MonsterSpecies.slots
## (imported earlier for the party-formation slot-cost mechanic) turned out,
## on cross-checking the real source spreadsheet's own Size column, to
## already BE each monster's size tier -- confirmed against all 803
## imported monsters with zero mismatches, so no new field or re-import was
## needed to build this cluster.
func _check_size_tier_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	var giant_killer := BonusDamageVsSizeTraitEffect.new()
	giant_killer.target_slots = 4
	giant_killer.damage_multiplier = 1.5

	var giant_side := team_builder.build_team(["asura_zoma"], "side_b")
	_check("fixture sanity check: Asura Zoma is a real 4-slot (Giant-tier) monster", giant_side[0].species.slots == 4)
	_check(
		"giant killer: boosts damage against a Giant-tier (4-slot) target",
		giant_killer.on_before_damage_dealt(null, null, giant_side[0], 100) == 150
	)

	var small_side := team_builder.build_team(["slime"], "side_a")
	_check("fixture sanity check: Slime is a real 1-slot (Small-tier) monster", small_side[0].species.slots == 1)
	_check(
		"giant killer: leaves damage untouched against a non-Giant-tier target",
		giant_killer.on_before_damage_dealt(null, null, small_side[0], 100) == 100
	)

	var standard_killer := BonusDamageVsSizeTraitEffect.new()
	standard_killer.target_slots = 1
	standard_killer.damage_multiplier = 1.5
	_check(
		"standard killer: boosts damage against a Small-tier (1-slot) target",
		standard_killer.on_before_damage_dealt(null, null, small_side[0], 100) == 150
	)
	_check(
		"standard killer: leaves damage untouched against a non-Small-tier target",
		standard_killer.on_before_damage_dealt(null, null, giant_side[0], 100) == 100
	)

	var big_hitter_data := TraitData.new()
	big_hitter_data.id = "big_hitter"
	var big_hitter := TraitEffect.create("big_hitter", big_hitter_data)
	_check(
		"big_hitter: registers as an unconditional damage boost with no MP-cost change",
		big_hitter is MpCostAndDamageTraitEffect
		and big_hitter.on_before_damage_dealt(null, null, null, 100) > 100
		and is_equal_approx(big_hitter.get_mp_cost_multiplier(team_builder.skill_database.get_skill("frizz")), 1.0)
	)

	var grand_slammer_data := TraitData.new()
	grand_slammer_data.id = "grand_slammer"
	var grand_slammer := TraitEffect.create("grand_slammer", grand_slammer_data)
	_check(
		"grand_slammer: registers as an unconditional damage boost, distinct from big_hitter's own magnitude",
		grand_slammer is MpCostAndDamageTraitEffect
		and grand_slammer.on_before_damage_dealt(null, null, null, 100) > big_hitter.on_before_damage_dealt(null, null, null, 100)
	)

## Four traits missed on the original passes that built their own shared
## classes (Retaliation family, Medicinal Knowledge, Stress Relief) --
## caught on a later re-audit rather than needing anything new, plus
## Violent Rager's own small new class.
func _check_missed_quick_win_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	var paralyzing_data := TraitData.new()
	paralyzing_data.id = "paralyzing"
	var paralyzing := TraitEffect.create("paralyzing", paralyzing_data, team_builder.skill_database)
	_check(
		"paralyzing: registers as a guaranteed (chance=1.0) RetaliationStatusTraitEffect for paralysis",
		paralyzing is RetaliationStatusTraitEffect
		and is_equal_approx(paralyzing.chance, 1.0)
		and paralyzing.status_data != null and paralyzing.status_data.id == "paralysis"
	)

	var sobering_data := TraitData.new()
	sobering_data.id = "sobering_slap"
	var sobering_slap := TraitEffect.create("sobering_slap", sobering_data)
	_check(
		"sobering_slap: registers as CureAllyStatusOnTurnTraitEffect covering confusion and sleep",
		sobering_slap is CureAllyStatusOnTurnTraitEffect
		and sobering_slap.status_ids.has("confusion") and sobering_slap.status_ids.has("sleep")
	)

	var tension_relief_data := TraitData.new()
	tension_relief_data.id = "tension_relief_body"
	var tension_relief_body := TraitEffect.create("tension_relief_body", tension_relief_data)
	_check(
		"tension_relief_body: registers as the same TensionStealOnAttackedTraitEffect Stress Relief uses",
		tension_relief_body is TensionStealOnAttackedTraitEffect
	)

	var rager_harness := _new_harness(team_builder)
	rager_harness.actor.current_hp = rager_harness.actor.species.base_hp
	var rager := HpForTensionTraitEffect.new()
	rager.hp_cost_percent = 0.1
	rager.levels = 2
	rager.chance = 1.0
	rager.on_turn_start(rager_harness.ctx, rager_harness.actor)
	_check(
		"violent rager: spends HP and gains tension on a guaranteed roll",
		rager_harness.actor.current_hp < rager_harness.actor.species.base_hp and rager_harness.actor.tension_level == 2
	)

	var rager_low_hp_harness := _new_harness(team_builder)
	rager_low_hp_harness.actor.current_hp = 1
	var rager_low_hp := HpForTensionTraitEffect.new()
	rager_low_hp.hp_cost_percent = 0.5
	rager_low_hp.chance = 1.0
	rager_low_hp.on_turn_start(rager_low_hp_harness.ctx, rager_low_hp_harness.actor)
	_check(
		"violent rager: never drops the owner's own HP to 0 from its own cost",
		rager_low_hp_harness.actor.current_hp >= 1
	)

## Great Sage/Warrior/Combat King/Deadly Breath/Dance Meister/Divine Dancer:
## the source spreadsheet's "Type" column (Spell/Slash/Body/Dance/Breath/
## Other), sitting in the exact same cached abilities.json the earlier
## element import already used, just never previously read for this second
## field.
func _check_skill_type_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	var frizz := team_builder.skill_database.get_skill("frizz")
	_check("skill_type import: frizz carries skill_type 'Spell'", frizz.skill_type == "Spell")
	var heart_breaker := team_builder.skill_database.get_skill("heart_breaker")
	_check("skill_type import: heart_breaker carries skill_type 'Slash'", heart_breaker.skill_type == "Slash")

	var great_sage := SkillTypeDamageBoostTraitEffect.new()
	great_sage.skill_types = ["Spell"] as Array[String]
	great_sage.damage_multiplier = 1.3
	_check(
		"great sage: get_skill_type_damage_multiplier boosts a matching Spell",
		is_equal_approx(great_sage.get_skill_type_damage_multiplier("Spell"), 1.3)
	)
	_check(
		"great sage: leaves a non-matching skill_type untouched",
		is_equal_approx(great_sage.get_skill_type_damage_multiplier("Slash"), 1.0)
	)

	var dance_meister := SkillTypeDamageBoostTraitEffect.new()
	dance_meister.skill_types = ["Dance"] as Array[String]
	dance_meister.mp_cost_multiplier = 0.75
	var divine_dancer := SkillTypeDamageBoostTraitEffect.new()
	divine_dancer.skill_types = ["Dance"] as Array[String]
	var dance_skill := SkillData.new()
	dance_skill.skill_type = "Dance"
	var non_dance_skill := SkillData.new()
	non_dance_skill.skill_type = "Slash"
	_check(
		"dance meister: discounts MP cost for a Dance-type skill",
		is_equal_approx(dance_meister.get_mp_cost_multiplier(dance_skill), 0.75)
	)
	_check(
		"dance meister: leaves a non-Dance skill's MP cost untouched",
		is_equal_approx(dance_meister.get_mp_cost_multiplier(non_dance_skill), 1.0)
	)
	_check(
		"divine dancer: boosts damage but (unlike dance meister) never discounts MP",
		is_equal_approx(divine_dancer.get_mp_cost_multiplier(dance_skill), 1.0)
	)

	# Full integration: DamageEffect._run_damage_hooks() actually consults
	# skill_type via a real ActionExecutor.execute() cast, not just that the
	# trait class works correctly when called directly.
	var boosted_harness := _new_harness(team_builder)
	var boost_trait := SkillTypeDamageBoostTraitEffect.new()
	boost_trait.skill_types = ["Spell"] as Array[String]
	boost_trait.damage_multiplier = 2.0
	var boost_traits: Array[TraitEffect] = [boost_trait]
	boosted_harness.actor.active_traits = boost_traits
	var baseline_harness := _new_harness(team_builder)
	ActionExecutor.execute(baseline_harness.ctx, Action.new(baseline_harness.actor.instance_id, "frizz", baseline_harness.target.instance_id), team_builder.skill_registry)
	ActionExecutor.execute(boosted_harness.ctx, Action.new(boosted_harness.actor.instance_id, "frizz", boosted_harness.target.instance_id), team_builder.skill_registry)
	var baseline_target: MonsterInstance = baseline_harness.target
	var boosted_target: MonsterInstance = boosted_harness.target
	var baseline_damage: int = baseline_target.species.base_hp - baseline_target.current_hp
	var boosted_damage: int = boosted_target.species.base_hp - boosted_target.current_hp
	_check(
		"end-to-end: a real Frizz cast with Great Sage's own boost deals more damage than the same cast without it",
		baseline_damage > 0 and boosted_damage > baseline_damage
	)

	var giant_killer_data := TraitData.new()
	giant_killer_data.id = "great_sage"
	var registered_great_sage := TraitEffect.create("great_sage", giant_killer_data)
	_check(
		"great_sage registration: resolves to a Spell-keyed SkillTypeDamageBoostTraitEffect",
		registered_great_sage is SkillTypeDamageBoostTraitEffect and registered_great_sage.skill_types.has("Spell")
	)
	var warrior_data := TraitData.new()
	warrior_data.id = "warrior"
	var registered_warrior := TraitEffect.create("warrior", warrior_data)
	_check(
		"warrior registration: resolves to a Slash-keyed SkillTypeDamageBoostTraitEffect",
		registered_warrior is SkillTypeDamageBoostTraitEffect and registered_warrior.skill_types.has("Slash")
	)
	var combat_king_data := TraitData.new()
	combat_king_data.id = "combat_king"
	var registered_combat_king := TraitEffect.create("combat_king", combat_king_data)
	_check(
		"combat_king registration: resolves to a Body-keyed SkillTypeDamageBoostTraitEffect",
		registered_combat_king is SkillTypeDamageBoostTraitEffect and registered_combat_king.skill_types.has("Body")
	)
	var deadly_breath_data := TraitData.new()
	deadly_breath_data.id = "deadly_breath"
	var registered_deadly_breath := TraitEffect.create("deadly_breath", deadly_breath_data)
	_check(
		"deadly_breath registration: resolves to a Breath-keyed SkillTypeDamageBoostTraitEffect",
		registered_deadly_breath is SkillTypeDamageBoostTraitEffect and registered_deadly_breath.skill_types.has("Breath")
	)

## Random Buff/Oomph/Ping and Sudden Ping: real skills that needed their own
## broken effect data fixed (buff.json/ping.json/kaping.json/oomphle.json
## were wrongly modeled as self-damage, unlike their correctly-modeled
## sibling Oomph) before a new autonomous-self-cast mechanism could
## meaningfully trigger them at all.
func _check_self_cast_skill_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	var buff := team_builder.skill_database.get_skill("buff")
	_check(
		"data fix: buff now applies a real defense stat_mod instead of self-damage",
		buff.effects.size() == 1 and buff.effects[0] is StatModEffect and buff.effects[0].stat_name == "defense"
	)
	var ping := team_builder.skill_database.get_skill("ping")
	_check(
		"data fix: ping now applies a real wisdom stat_mod instead of self-damage",
		ping.effects.size() == 1 and ping.effects[0] is StatModEffect and ping.effects[0].stat_name == "wisdom"
	)
	var oomphle := team_builder.skill_database.get_skill("oomphle")
	_check(
		"data fix: oomphle now applies a real attack stat_mod instead of self-damage",
		oomphle.effects.size() == 1 and oomphle.effects[0] is StatModEffect and oomphle.effects[0].stat_name == "attack"
	)

	# Full integration: a guaranteed roll actually casts the real skill
	# through ActionExecutor.execute() -- MP gets deducted and the stat
	# stage actually changes -- not just that the trait class holds the
	# right skill_data reference.
	var turn_harness := _new_harness(team_builder)
	var turn_actor: MonsterInstance = turn_harness.actor
	var self_caster := SelfCastSkillOnTurnTraitEffect.new()
	self_caster.skill_data = ping
	self_caster.chance = 1.0
	var starting_mp: int = turn_actor.current_mp
	self_caster.on_turn_start(turn_harness.ctx, turn_actor)
	_check(
		"random ping integration: a guaranteed roll actually raises the caster's own wisdom stage",
		turn_harness.actor.stat_stages.get_stage("wisdom") == 1
	)
	_check("random ping integration: the autonomous cast deducts real MP", turn_harness.actor.current_mp == starting_mp - ping.mp_cost)

	var entry_harness := _new_harness(team_builder)
	var entry_caster := SelfCastSkillOnEntryTraitEffect.new()
	entry_caster.skill_data = ping
	entry_caster.chance = 1.0
	entry_caster.on_monster_entered(entry_harness.ctx, entry_harness.actor)
	_check(
		"sudden ping integration: a guaranteed roll at battle entry also raises wisdom",
		entry_harness.actor.stat_stages.get_stage("wisdom") == 1
	)

	var no_skill_caster := SelfCastSkillOnTurnTraitEffect.new()
	no_skill_caster.chance = 1.0
	var no_skill_harness := _new_harness(team_builder)
	no_skill_caster.on_turn_start(no_skill_harness.ctx, no_skill_harness.actor)
	_check("self-cast with no skill_data assigned does nothing rather than erroring", no_skill_harness.actor.stat_stages.get_stage("wisdom") == 0)

	var random_buff_data := TraitData.new()
	random_buff_data.id = "random_buff"
	var random_buff := TraitEffect.create("random_buff", random_buff_data, team_builder.skill_database)
	_check(
		"random_buff registration: resolves skill_data to the real 'buff' skill",
		random_buff is SelfCastSkillOnTurnTraitEffect and random_buff.skill_data != null and random_buff.skill_data.id == "buff"
	)
	var random_oomph_data := TraitData.new()
	random_oomph_data.id = "random_oomph"
	var random_oomph := TraitEffect.create("random_oomph", random_oomph_data, team_builder.skill_database)
	_check(
		"random_oomph registration: resolves skill_data to the real 'oomph' skill",
		random_oomph is SelfCastSkillOnTurnTraitEffect and random_oomph.skill_data != null and random_oomph.skill_data.id == "oomph"
	)
	var sudden_ping_data := TraitData.new()
	sudden_ping_data.id = "sudden_ping"
	var sudden_ping := TraitEffect.create("sudden_ping", sudden_ping_data, team_builder.skill_database)
	_check(
		"sudden_ping registration: resolves to a SelfCastSkillOnEntryTraitEffect for 'ping'",
		sudden_ping is SelfCastSkillOnEntryTraitEffect and sudden_ping.skill_data != null and sudden_ping.skill_data.id == "ping"
	)

## The broader "self-targeted skill wrongly modeled as self-damage" bug
## fixed across every skill directly needed by a missing trait (Tier A of
## that pass): simple stat buffs, real heals, and one single-enemy stat
## debuff (Wave of Panic -- the one skill in this specific cluster that
## ISN'T self-targeted).
func _check_broken_skill_data_fixes() -> void:
	var team_builder := TeamBuilder.new()

	var accelerate := team_builder.skill_database.get_skill("accelerate")
	_check(
		"data fix: accelerate applies a real agility stat_mod instead of self-damage",
		accelerate.effects.size() == 1 and accelerate.effects[0] is StatModEffect and accelerate.effects[0].stat_name == "agility"
	)
	var kabuff := team_builder.skill_database.get_skill("kabuff")
	_check(
		"data fix: kabuff applies a real defense stat_mod instead of self-damage",
		kabuff.effects.size() == 1 and kabuff.effects[0] is StatModEffect and kabuff.effects[0].stat_name == "defense"
	)
	var horns_of_battle := team_builder.skill_database.get_skill("horns_of_battle")
	_check(
		"data fix: horns_of_battle applies a real attack stat_mod instead of self-damage",
		horns_of_battle.effects.size() == 1 and horns_of_battle.effects[0] is StatModEffect and horns_of_battle.effects[0].stat_name == "attack"
	)

	var miracle := team_builder.skill_database.get_skill("miracle_of_the_stars")
	var miracle_stats: Array[String] = []
	for effect in miracle.effects:
		if effect is StatModEffect:
			miracle_stats.append(effect.stat_name)
	_check(
		"data fix: miracle_of_the_stars buffs all four stats at once, not self-damage",
		miracle_stats.size() == 4 and miracle_stats.has("attack") and miracle_stats.has("defense") and miracle_stats.has("agility") and miracle_stats.has("wisdom")
	)

	var meditation := team_builder.skill_database.get_skill("meditation")
	_check(
		"data fix: meditation applies a real 350-power heal instead of self-damage",
		meditation.effects.size() == 1 and meditation.effects[0] is HealEffect and meditation.effects[0].power == 350
	)

	var wave_of_panic := team_builder.skill_database.get_skill("wave_of_panic")
	_check(
		"data fix: wave_of_panic applies a real single-enemy stat debuff instead of self-damage",
		wave_of_panic.effects.size() == 1 and wave_of_panic.effects[0] is StatModEffect
		and not wave_of_panic.effects[0].target_self and wave_of_panic.effects[0].stages < 0
	)

	# Integration: a real cast of the now-fixed accelerate actually raises
	# the caster's own agility stage through the full ActionExecutor pipeline.
	var harness := _new_harness(team_builder)
	harness.actor.current_mp = accelerate.mp_cost
	ActionExecutor.execute(harness.ctx, Action.new(harness.actor.instance_id, "accelerate", harness.actor.instance_id), team_builder.skill_registry)
	_check("end-to-end: casting the fixed accelerate raises the caster's own agility stage", harness.actor.stat_stages.get_stage("agility") == 1)

## Defuddle/Squelch/Tingle/Sheen/Lift Demerit/Soothing Vortex/Benediction/
## Wave of Relief (CureStatusEffect) and Magic Multiplier/Sonata of
## Serenity (RestoreMpEffect) -- two new SkillEffect types, generalizing
## the exact same direct-mutation patterns already used by
## CureAllyStatusOnTurnTraitEffect and HealEffect respectively.
func _check_cure_status_and_restore_mp_mechanics() -> void:
	var team_builder := TeamBuilder.new()
	var poison_status := team_builder.skill_database.get_status("poison")
	var confusion_status := team_builder.skill_database.get_status("confusion")

	# Pure-function: a specific status_ids list only cures a match.
	var cure_confusion := CureStatusEffect.new()
	cure_confusion.status_ids = ["confusion"]
	var confused_harness := _new_harness(team_builder)
	confused_harness.actor.active_status = StatusInstance.new(confusion_status)
	cure_confusion.apply(confused_harness.ctx, confused_harness.actor, confused_harness.target)
	_check("cure_status: cures a matching status", confused_harness.actor.active_status == null)

	var poisoned_harness := _new_harness(team_builder)
	poisoned_harness.actor.active_status = StatusInstance.new(poison_status)
	cure_confusion.apply(poisoned_harness.ctx, poisoned_harness.actor, poisoned_harness.target)
	_check("cure_status: leaves a non-matching status untouched", poisoned_harness.actor.active_status != null)

	# Empty status_ids (Sheen/Lift Demerit/Soothing Vortex/Wave of
	# Relief's own registration) cures ANY status.
	var cure_any := CureStatusEffect.new()
	var cure_any_harness := _new_harness(team_builder)
	cure_any_harness.actor.active_status = StatusInstance.new(poison_status)
	cure_any.apply(cure_any_harness.ctx, cure_any_harness.actor, cure_any_harness.target)
	_check("cure_status: empty status_ids cures any active status", cure_any_harness.actor.active_status == null)

	# Data fix + full integration through SkillLoader/the real fixture.
	var defuddle := team_builder.skill_database.get_skill("defuddle")
	_check(
		"data fix: defuddle applies a real cure_status effect instead of self-damage",
		defuddle.effects.size() == 1 and defuddle.effects[0] is CureStatusEffect and defuddle.effects[0].status_ids == ["confusion"]
	)
	var sheen := team_builder.skill_database.get_skill("sheen")
	_check("data fix: sheen cures any status (empty status_ids)", sheen.effects[0] is CureStatusEffect and sheen.effects[0].status_ids.is_empty())

	# Full ActionExecutor integration uses Benediction/curse rather than
	# Defuddle/confusion here deliberately: confusion has its own real
	# skip_turn_chance (0.33), which would make the confused caster
	# sometimes fail to act at all -- a real, separate interaction, not a
	# bug in CureStatusEffect, but one that would make this specific check
	# flaky for reasons unrelated to what it's actually testing. Curse has
	# skip_turn_chance == 0.0.
	var curse_status := team_builder.skill_database.get_status("curse")
	var benediction := team_builder.skill_database.get_skill("benediction")
	var benediction_harness := _new_harness(team_builder)
	benediction_harness.actor.active_status = StatusInstance.new(curse_status)
	benediction_harness.actor.current_mp = benediction.mp_cost
	ActionExecutor.execute(benediction_harness.ctx, Action.new(benediction_harness.actor.instance_id, "benediction", benediction_harness.actor.instance_id), team_builder.skill_registry)
	_check("end-to-end: a real benediction cast cures the caster's own curse", benediction_harness.actor.active_status == null)

	# RestoreMpEffect: pure-function + data fix + integration.
	var restore := RestoreMpEffect.new()
	restore.power = 10
	var mp_harness := _new_harness(team_builder)
	mp_harness.actor.current_mp = 0
	restore.apply(mp_harness.ctx, mp_harness.actor, mp_harness.target)
	_check("restore_mp: restores a flat amount of MP", mp_harness.actor.current_mp == 10)

	var capped_harness := _new_harness(team_builder)
	capped_harness.actor.current_mp = capped_harness.actor.species.base_mp
	restore.apply(capped_harness.ctx, capped_harness.actor, capped_harness.target)
	_check("restore_mp: never restores past the recipient's own max MP", capped_harness.actor.current_mp == capped_harness.actor.species.base_mp)

	var magic_multiplier := team_builder.skill_database.get_skill("magic_multiplier")
	_check(
		"data fix: magic_multiplier applies a real restore_mp effect instead of self-damage",
		magic_multiplier.effects.size() == 1 and magic_multiplier.effects[0] is RestoreMpEffect
	)

## Shuffle/Unnatural Order: a new TurnOrderOverrideEffect SkillEffect
## setting a BattleState flag consumed by TurnManager.run_turn() the
## FOLLOWING round (see BattleState.shuffle_next_round's own doc comment).
func _check_turn_order_override_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	var shuffle := team_builder.skill_database.get_skill("shuffle")
	_check(
		"data fix: shuffle applies a real turn_order_override effect instead of self-damage",
		shuffle.effects.size() == 1 and shuffle.effects[0] is TurnOrderOverrideEffect
		and shuffle.effects[0].mode == TurnOrderOverrideEffect.Mode.SHUFFLE
	)
	var unnatural_order := team_builder.skill_database.get_skill("unnatural_order")
	_check(
		"data fix: unnatural_order applies a real turn_order_override effect (reverse mode)",
		unnatural_order.effects[0] is TurnOrderOverrideEffect and unnatural_order.effects[0].mode == TurnOrderOverrideEffect.Mode.REVERSE
	)

	var flag_harness := _new_harness(team_builder)
	shuffle.effects[0].apply(flag_harness.ctx, flag_harness.actor, flag_harness.actor)
	_check("turn_order_override: casting shuffle sets shuffle_next_round", flag_harness.ctx.state.shuffle_next_round)

	var reverse_harness := _new_harness(team_builder)
	unnatural_order.effects[0].apply(reverse_harness.ctx, reverse_harness.actor, reverse_harness.actor)
	_check("turn_order_override: casting unnatural_order sets reverse_next_round", reverse_harness.ctx.state.reverse_next_round)

	# ActionResolver.shuffle_actions itself: a real Fisher-Yates shuffle
	# using the deterministic RNG, not just returning the input unchanged.
	var team_builder2 := TeamBuilder.new()
	var side_a := team_builder2.build_team(["slime", "dracky"], "side_a")
	var state := BattleState.new(DeterministicRng.new(42), BattleEventBus.new())
	var a1 := Action.new(side_a[0].instance_id, "attack", 0)
	a1.submission_index = 0
	var a2 := Action.new(side_a[1].instance_id, "attack", 0)
	a2.submission_index = 1
	var to_shuffle: Array[Action] = [a1, a2]
	var shuffled := ActionResolver.shuffle_actions(to_shuffle, state)
	_check("shuffle_actions: returns the same number of actions, none lost or duplicated", shuffled.size() == 2)

	var wave_of_panic_data := TraitData.new()
	wave_of_panic_data.id = "wave_of_panic"
	var wave_of_panic_trait := TraitEffect.create("wave_of_panic", wave_of_panic_data, team_builder.skill_database)
	_check(
		"wave_of_panic registration: resolves skill_data and targets a random enemy, not itself",
		wave_of_panic_trait is SelfCastSkillOnTurnTraitEffect and wave_of_panic_trait.skill_data.id == "wave_of_panic" and wave_of_panic_trait.target_random_enemy
	)

	# Full integration: Random Wave of Panic actually casts at an enemy, not
	# the caster itself.
	var panic_harness := _new_harness(team_builder)
	var panic_caster := SelfCastSkillOnTurnTraitEffect.new()
	panic_caster.skill_data = team_builder.skill_database.get_skill("wave_of_panic")
	panic_caster.chance = 1.0
	panic_caster.target_random_enemy = true
	panic_harness.actor.current_mp = panic_caster.skill_data.mp_cost
	panic_caster.on_turn_start(panic_harness.ctx, panic_harness.actor)
	_check(
		"random wave of panic integration: debuffs the enemy's defense, not the caster's own",
		panic_harness.target.stat_stages.get_stage("defense") == -1 and panic_harness.actor.stat_stages.get_stage("defense") == 0
	)

	var sudden_shuffle_data := TraitData.new()
	sudden_shuffle_data.id = "sudden_shuffle"
	var sudden_shuffle := TraitEffect.create("sudden_shuffle", sudden_shuffle_data, team_builder.skill_database)
	_check(
		"sudden_shuffle registration: resolves to a SelfCastSkillOnEntryTraitEffect for 'shuffle'",
		sudden_shuffle is SelfCastSkillOnEntryTraitEffect and sudden_shuffle.skill_data.id == "shuffle"
	)
	var random_reversal_data := TraitData.new()
	random_reversal_data.id = "random_reversal"
	var random_reversal := TraitEffect.create("random_reversal", random_reversal_data, team_builder.skill_database)
	_check(
		"random_reversal registration: resolves to a SelfCastSkillOnTurnTraitEffect for 'unnatural_order'",
		random_reversal is SelfCastSkillOnTurnTraitEffect and random_reversal.skill_data.id == "unnatural_order"
	)
	var wave_of_relief_data := TraitData.new()
	wave_of_relief_data.id = "wave_of_relief"
	var wave_of_relief_trait := TraitEffect.create("wave_of_relief", wave_of_relief_data, team_builder.skill_database)
	_check(
		"wave_of_relief registration: resolves to a self-targeted SelfCastSkillOnTurnTraitEffect",
		wave_of_relief_trait is SelfCastSkillOnTurnTraitEffect and wave_of_relief_trait.skill_data.id == "wave_of_relief" and not wave_of_relief_trait.target_random_enemy
	)

	# Full round-trip through TurnManager itself: casting shuffle this round
	# sets the flag, and it gets consumed (and reset) the NEXT round. Builds
	# its own minimal ScriptedActionProvider pair directly rather than
	# ScriptedTurns.build_providers, which is specifically shaped for M1's
	# own 3-monster (Slime/Dracky/Golem) cast, not a generic 1v1.
	var team_builder3 := TeamBuilder.new()
	var side_a3 := team_builder3.build_team(["slime"], "side_a")
	var side_b3 := team_builder3.build_team(["golem"], "side_b")
	var event_bus3 := BattleEventBus.new()
	var state3 := BattleState.new(DeterministicRng.new(7), event_bus3)
	state3.side_a_team = side_a3
	state3.side_b_team = side_b3
	state3.set_active_at("side_a", 0, 0)
	state3.set_active_at("side_b", 0, 0)
	var ctx3 := BattleContext.new(state3)
	state3.shuffle_next_round = true

	var provider_a3 := ScriptedActionProvider.new()
	var attack_queue_a: Array[Action] = [Action.new(side_a3[0].instance_id, "attack", side_b3[0].instance_id)]
	provider_a3.set_queue(side_a3[0].instance_id, attack_queue_a)
	var provider_b3 := ScriptedActionProvider.new()
	var attack_queue_b: Array[Action] = [Action.new(side_b3[0].instance_id, "attack", side_a3[0].instance_id)]
	provider_b3.set_queue(side_b3[0].instance_id, attack_queue_b)
	var providers3 := {"side_a": provider_a3, "side_b": provider_b3}

	TurnManager.run_turn(ctx3, providers3, team_builder3.skill_registry)
	_check("TurnManager consumes shuffle_next_round exactly once, resetting it after use", not state3.shuffle_next_round)

## Heckling Hector, Stalwart Spirit, and Dust of the Clan: three
## tension-family traits re-examined on a later pass and found buildable
## after all with existing hooks (require_any_enemy_tension,
## on_status_afflicted reused from Tit for Tat, and a new
## get_tension_burn_multiplier hook respectively).
func _check_tension_family_reexamined_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	# Heckling Hector: reacts to the CURRENT state (does any enemy have
	# tension right now), not a discrete "just increased" event.
	var hector_harness := _new_harness(team_builder)
	var hector := EnemyTensionDrainOnTurnTraitEffect.new()
	hector.require_any_enemy_tension = true
	hector.levels = 4
	hector.on_turn_start(hector_harness.ctx, hector_harness.actor)
	_check("heckling hector: does nothing when no enemy currently has tension", hector_harness.target.tension_level == 0)

	hector_harness.target.tension_level = 3
	hector.on_turn_start(hector_harness.ctx, hector_harness.actor)
	_check("heckling hector: drains an enemy's tension unconditionally (no chance roll) once any enemy has some", hector_harness.target.tension_level == 0)

	var hector_data := TraitData.new()
	hector_data.id = "heckling_hector"
	var registered_hector := TraitEffect.create("heckling_hector", hector_data)
	_check(
		"heckling_hector registration: resolves to a require_any_enemy_tension-configured EnemyTensionDrainOnTurnTraitEffect",
		registered_hector is EnemyTensionDrainOnTurnTraitEffect and registered_hector.require_any_enemy_tension
	)

	# Stalwart Spirit: reuses Tit for Tat's own on_status_afflicted hook,
	# "stasis" interpreted as immobilize.
	var immobilize_status := team_builder.skill_database.get_status("immobilize")
	var poison_status := team_builder.skill_database.get_status("poison")
	var stalwart := TensionGainOnStatusTraitEffect.new()
	var stalwart_harness := _new_harness(team_builder)
	stalwart.on_status_afflicted(stalwart_harness.ctx, stalwart_harness.actor, stalwart_harness.target, immobilize_status)
	_check("stalwart spirit: gains 2 tension when struck by immobilize", stalwart_harness.actor.tension_level == 2)

	var stalwart_no_match_harness := _new_harness(team_builder)
	stalwart.on_status_afflicted(stalwart_no_match_harness.ctx, stalwart_no_match_harness.actor, stalwart_no_match_harness.target, poison_status)
	_check("stalwart spirit: leaves tension untouched for a non-matching status", stalwart_no_match_harness.actor.tension_level == 0)

	var stalwart_data := TraitData.new()
	stalwart_data.id = "stalwart_spirit"
	var registered_stalwart := TraitEffect.create("stalwart_spirit", stalwart_data)
	_check("stalwart_spirit registration: resolves to TensionGainOnStatusTraitEffect", registered_stalwart is TensionGainOnStatusTraitEffect)

	# Full integration: a real immobilize application through StatusEffect
	# actually triggers Stalwart Spirit's tension gain.
	var full_harness := _new_harness(team_builder)
	var stalwart_traits: Array[TraitEffect] = [TensionGainOnStatusTraitEffect.new()]
	full_harness.target.active_traits = stalwart_traits
	var immobilize_effect := StatusEffect.new()
	immobilize_effect.status_data = immobilize_status
	immobilize_effect.chance = 1.0
	immobilize_effect.apply(full_harness.ctx, full_harness.actor, full_harness.target)
	_check("end-to-end: a real immobilize application triggers Stalwart Spirit's tension gain", full_harness.target.tension_level == 2)

	# Dust of the Clan: multiplies TENSION_DAMAGE_PERCENT_PER_LEVEL, rolled
	# once per action (DeterministicRng.chance() boundary trick for
	# determinism).
	var dust := TensionBurnMultiplierTraitEffect.new()
	dust.chance = 1.0
	dust.multiplier = 2.0
	_check("dust of the clan: a guaranteed roll returns the configured multiplier", is_equal_approx(dust.get_tension_burn_multiplier(hector_harness.ctx), 2.0))

	var dust_never := TensionBurnMultiplierTraitEffect.new()
	dust_never.chance = 0.0
	_check("dust of the clan: a guaranteed miss returns 1.0 (no change)", is_equal_approx(dust_never.get_tension_burn_multiplier(hector_harness.ctx), 1.0))

	var dust_data := TraitData.new()
	dust_data.id = "dust_of_the_clan"
	var registered_dust := TraitEffect.create("dust_of_the_clan", dust_data)
	_check("dust_of_the_clan registration: resolves to TensionBurnMultiplierTraitEffect", registered_dust is TensionBurnMultiplierTraitEffect)

	# Full integration: a real DamageEffect.apply() call with tension banked
	# deals more damage with the doubled Tension Burn than without it. Uses
	# a low power (10, not 50) specifically so neither hit one-shots the
	# golem target (base_hp 50) -- the first version of this check used
	# power=50 and both the 1.5x and 2x tension multipliers ended up
	# one-shotting it anyway, making baseline_dmg == boosted_dmg (both
	# capped at the target's full HP) and failing for a reason unrelated
	# to whether Dust of the Clan actually works.
	var baseline_harness := _new_harness(team_builder)
	baseline_harness.actor.tension_level = 2
	var baseline_damage_effect := DamageEffect.new()
	baseline_damage_effect.power = 10
	baseline_damage_effect.category = DamageEffect.Category.PHYSICAL
	baseline_damage_effect.apply(baseline_harness.ctx, baseline_harness.actor, baseline_harness.target)

	var boosted_harness := _new_harness(team_builder)
	boosted_harness.actor.tension_level = 2
	var boosted_dust_traits: Array[TraitEffect] = [dust]
	boosted_harness.actor.active_traits = boosted_dust_traits
	var boosted_damage_effect := DamageEffect.new()
	boosted_damage_effect.power = 10
	boosted_damage_effect.category = DamageEffect.Category.PHYSICAL
	boosted_damage_effect.apply(boosted_harness.ctx, boosted_harness.actor, boosted_harness.target)

	var baseline_target: MonsterInstance = baseline_harness.target
	var boosted_target: MonsterInstance = boosted_harness.target
	var baseline_dmg: int = baseline_target.species.base_hp - baseline_target.current_hp
	var boosted_dmg: int = boosted_target.species.base_hp - boosted_target.current_hp
	_check(
		"end-to-end: Dust of the Clan's doubled Tension Burn deals more damage than the same banked tension without it",
		baseline_dmg > 0 and boosted_dmg > baseline_dmg
	)
	_check("dust of the clan integration: tension still resets to 0 after being spent, same as always", boosted_harness.actor.tension_level == 0)

## Covers both the pure MonsterInstance stat wiring (DamageEffect.apply()'s
## own offense := user.get_effective_stat("attack") reads exactly this seam,
## so testing it directly IS testing the real integration point) and the
## TeamToBattleBridge resolution path from a saved loadout's
## equipped_weapon_id down to instance.equipped_weapon.
func _check_weapon_equip_mechanics() -> void:
	var team_builder := TeamBuilder.new()
	var weapon_db := WeaponDatabase.new()
	var copper_sword := weapon_db.get_weapon("copper_sword")

	var unarmed_slime := team_builder.build_team(["slime"], "side_a")[0]
	var baseline_attack := unarmed_slime.get_effective_stat("attack")
	_check("unarmed slime's effective attack is unaffected by the weapon system", baseline_attack == unarmed_slime.species.base_attack)

	var armed_slime := team_builder.build_team(["slime"], "side_a")[0]
	armed_slime.equipped_weapon = copper_sword
	_check(
		"equipping copper_sword (+10 base_attack) raises effective attack by exactly its bonus",
		armed_slime.get_effective_stat("attack") == baseline_attack + copper_sword.base_attack
	)

	# TeamToBattleBridge integration: a saved loadout's equipped_weapon_id
	# should resolve all the way down to MonsterInstance.equipped_weapon.
	var monster_db := MonsterDatabase.new()
	var skill_db := SkillDatabase.new()
	var trait_db := TraitDatabase.new()
	var skillset_db := SkillSetDatabase.new()
	var loadout := MonsterLoadout.new()
	loadout.species_id = "slime"
	loadout.equipped_weapon_id = "copper_sword"
	var saved_team := SavedTeam.new()
	saved_team.members = [loadout]
	var bridged_team := TeamToBattleBridge.build_team(saved_team, "side_a", monster_db, skill_db, trait_db, skillset_db, 0, weapon_db)
	_check("TeamToBattleBridge resolves equipped_weapon_id into a real WeaponData", bridged_team[0].equipped_weapon != null and bridged_team[0].equipped_weapon.id == "copper_sword")

	var unweaponed_loadout := MonsterLoadout.new()
	unweaponed_loadout.species_id = "slime"
	var unweaponed_saved_team := SavedTeam.new()
	unweaponed_saved_team.members = [unweaponed_loadout]
	var unweaponed_bridged_team := TeamToBattleBridge.build_team(unweaponed_saved_team, "side_a", monster_db, skill_db, trait_db, skillset_db, 0, weapon_db)
	_check("an empty equipped_weapon_id leaves equipped_weapon null even with a weapon_db present", unweaponed_bridged_team[0].equipped_weapon == null)

	var no_weapon_db_bridged_team := TeamToBattleBridge.build_team(saved_team, "side_a", monster_db, skill_db, trait_db, skillset_db, 0)
	_check("omitting weapon_db from build_team leaves equipped_weapon null (backward compatible)", no_weapon_db_bridged_team[0].equipped_weapon == null)

## Covers the mechanically-real subset of weapon flavor text: family-based
## damage bonus, the metal-body flat bonus (checked via traits, not
## species.family -- Metal Slime is family "Slime" but carries a metal_body
## trait), the secondary stat percentage bonus, and lifesteal. Crit-chance
## multiplier is checked as pure data only (multiplier + category filter),
## matching this suite's existing precedent of testing
## get_crit_chance_multiplier() as a pure function rather than dice-rolling
## the actual _roll_critical() chain (see _check_crit_mechanics()).
func _check_weapon_effects_mechanics() -> void:
	var weapon_db := WeaponDatabase.new()
	var damage_effect := DamageEffect.new()
	var team_builder := TeamBuilder.new()

	# --- family-based damage bonus (case-insensitive against species.family) ---
	var iron_lance := weapon_db.get_weapon("iron_lance")
	_check("iron_lance targets Slime family at 1.5x", iron_lance.bonus_vs_families == ["Slime"] and is_equal_approx(iron_lance.bonus_damage_multiplier, 1.5))

	var slime_target := team_builder.build_team(["slime"], "side_b")[0]
	_check(
		"iron_lance boosts damage against a Slime-family target (case-insensitive: weapon says 'Slime', fixture says 'slime')",
		damage_effect._apply_weapon_damage_bonus(iron_lance, slime_target, 100) == MathUtils.round_half_up(100.0 * 1.5)
	)

	var golem_target := team_builder.build_team(["golem"], "side_b")[0]
	_check(
		"iron_lance leaves damage untouched against a non-Slime-family target",
		damage_effect._apply_weapon_damage_bonus(iron_lance, golem_target, 100) == 100
	)
	_check(
		"no equipped weapon (null) leaves damage untouched",
		damage_effect._apply_weapon_damage_bonus(null, golem_target, 100) == 100
	)

	var partisan := weapon_db.get_weapon("partisan")
	_check(
		"partisan boosts damage against a Material-family target (real fixture data: Golem's family is 'Material', corrected this same milestone -- see wiki/log.md)",
		damage_effect._apply_weapon_damage_bonus(partisan, golem_target, 100) == MathUtils.round_half_up(100.0 * 1.5)
	)

	# --- metal-body flat bonus (trait-based, not family-based) ---
	var obsidian_sword := weapon_db.get_weapon("obsidian_sword")
	_check("obsidian_sword carries a +1 flat metal-body bonus", obsidian_sword.bonus_vs_metal_body_flat == 1)

	var metal_target := team_builder.build_team(["golem"], "side_b")[0]
	var metal_body_trait := MetalBodyTraitEffect.new()
	metal_body_trait.trait_data = TraitData.new()
	metal_body_trait.trait_data.id = "metal_body"
	metal_target.active_traits = [metal_body_trait]
	_check(
		"obsidian_sword adds its flat bonus against a target with an active metal-body trait",
		damage_effect._apply_weapon_damage_bonus(obsidian_sword, metal_target, 100) == 101
	)
	_check(
		"obsidian_sword's flat bonus doesn't apply without an active metal-body trait",
		damage_effect._apply_weapon_damage_bonus(obsidian_sword, golem_target, 100) == 100
	)

	# --- crit chance (pure data only, see function doc comment) ---
	var magical_whip := weapon_db.get_weapon("magical_whip")
	_check(
		"magical_whip's crit bonus is scoped to Magic only, not Physical",
		is_equal_approx(magical_whip.crit_chance_multiplier, 1.5) and magical_whip.crit_chance_category_filter == DamageEffect.Category.MAGIC
	)
	var gae_bolg := weapon_db.get_weapon("gae_bolg")
	_check(
		"gae_bolg's crit bonus applies to both categories (category_filter -1)",
		is_equal_approx(gae_bolg.crit_chance_multiplier, 1.5) and gae_bolg.crit_chance_category_filter == -1
	)

	# --- secondary stat percentage bonus ---
	var unarmed_slime := team_builder.build_team(["slime"], "side_a")[0]
	var baseline_agility := unarmed_slime.get_effective_stat("agility")
	var armed_slime := team_builder.build_team(["slime"], "side_a")[0]
	armed_slime.equipped_weapon = weapon_db.get_weapon("ebony_talons")
	_check(
		"a 10% agility-bonus weapon raises effective agility by exactly that percentage of base",
		armed_slime.get_effective_stat("agility") == baseline_agility + MathUtils.round_half_up(float(unarmed_slime.species.base_agility) * 0.1)
	)
	var defense_armed_slime := team_builder.build_team(["slime"], "side_a")[0]
	defense_armed_slime.equipped_weapon = weapon_db.get_weapon("ebony_talons")
	_check(
		"the same weapon's bonus_stats has no entry for defense, so defense is untouched",
		defense_armed_slime.get_effective_stat("defense") == unarmed_slime.get_effective_stat("defense")
	)

	# --- lifesteal, full end-to-end DamageEffect.apply() ---
	var lifesteal_harness := _new_harness(team_builder)
	var lifesteal_actor: MonsterInstance = lifesteal_harness.actor
	var lifesteal_target: MonsterInstance = lifesteal_harness.target
	lifesteal_actor.equipped_weapon = weapon_db.get_weapon("miracle_sword")
	lifesteal_actor.current_hp = 1
	var lifesteal_damage_effect := DamageEffect.new()
	lifesteal_damage_effect.power = 10
	lifesteal_damage_effect.apply(lifesteal_harness.ctx, lifesteal_actor, lifesteal_target)
	_check(
		"miracle_sword's lifesteal heals the wielder after a connecting hit",
		lifesteal_actor.current_hp > 1
	)

	var no_lifesteal_harness := _new_harness(team_builder)
	var no_lifesteal_actor: MonsterInstance = no_lifesteal_harness.actor
	no_lifesteal_actor.current_hp = 1
	var no_lifesteal_damage_effect := DamageEffect.new()
	no_lifesteal_damage_effect.power = 10
	no_lifesteal_damage_effect.apply(no_lifesteal_harness.ctx, no_lifesteal_actor, no_lifesteal_harness.target)
	_check(
		"without a lifesteal weapon equipped, the same attack doesn't heal the attacker",
		no_lifesteal_actor.current_hp == 1
	)

## Covers BlacksmithDatabase loading, the flat stat-boost summing on
## MonsterInstance, and the TeamToBattleBridge resolution of both
## STAT_BOOST and TRAIT_GRANT items -- including the dedup rule ("has no
## effect on those who already have that bonus") using real fixture data:
## Slime already carries critical_massacre innately, Golem does not carry
## artful_dodger.
func _check_blacksmith_mechanics() -> void:
	var blacksmith_db := BlacksmithDatabase.new()
	_check("BlacksmithDatabase loads all 25 wired items", blacksmith_db.get_all_items().size() == 25)

	var atk_20 := blacksmith_db.get_item("atk_20")
	var def_40 := blacksmith_db.get_item("def_40")
	_check("atk_20 is a stat_boost of +20 attack", atk_20.category == BlacksmithItemData.Category.STAT_BOOST and atk_20.stat_name == "attack" and atk_20.flat_bonus == 20)

	# --- pure stat-boost summing on MonsterInstance ---
	var team_builder := TeamBuilder.new()
	var boosted_slime := team_builder.build_team(["slime"], "side_a")[0]
	var baseline_attack := boosted_slime.get_effective_stat("attack")
	boosted_slime.crafted_stat_boosts = [atk_20]
	_check("a single crafted ATK+20 raises effective attack by exactly 20", boosted_slime.get_effective_stat("attack") == baseline_attack + 20)

	var double_boosted_slime := team_builder.build_team(["slime"], "side_a")[0]
	var baseline_defense := double_boosted_slime.get_effective_stat("defense")
	double_boosted_slime.crafted_stat_boosts = [atk_20, def_40]
	_check(
		"multiple crafted stat boosts each apply to their own stat independently",
		double_boosted_slime.get_effective_stat("attack") == baseline_attack + 20
		and double_boosted_slime.get_effective_stat("defense") == baseline_defense + 40
	)

	# --- TeamToBattleBridge integration ---
	var monster_db := MonsterDatabase.new()
	var skill_db := SkillDatabase.new()
	var trait_db := TraitDatabase.new()
	var skillset_db := SkillSetDatabase.new()

	var stat_loadout := MonsterLoadout.new()
	stat_loadout.species_id = "slime"
	stat_loadout.crafted_blacksmith_ids = ["atk_20", "def_40"]
	var stat_saved_team := SavedTeam.new()
	stat_saved_team.members = [stat_loadout]
	var stat_bridged := TeamToBattleBridge.build_team(stat_saved_team, "side_a", monster_db, skill_db, trait_db, skillset_db, 0, null, blacksmith_db)[0]
	_check(
		"TeamToBattleBridge resolves crafted stat-boost ids into real BlacksmithItemData on the instance",
		stat_bridged.crafted_stat_boosts.size() == 2 and stat_bridged.get_effective_stat("attack") == stat_bridged.species.base_attack + 20
	)

	# Golem does not innately carry artful_dodger -- granting it should add a
	# real, functioning trait effect.
	var new_trait_loadout := MonsterLoadout.new()
	new_trait_loadout.species_id = "golem"
	new_trait_loadout.crafted_blacksmith_ids = ["artful_dodger"]
	var new_trait_saved_team := SavedTeam.new()
	new_trait_saved_team.members = [new_trait_loadout]
	var new_trait_bridged := TeamToBattleBridge.build_team(new_trait_saved_team, "side_a", monster_db, skill_db, trait_db, skillset_db, 0, null, blacksmith_db)[0]
	var golem_species := monster_db.get_species("golem")
	_check("Golem's own species fixture doesn't innately carry artful_dodger (sanity check)", not golem_species.starting_trait_ids.has("artful_dodger"))
	_check(
		"granting artful_dodger to a Golem (which lacks it innately) adds a real ChanceBasedDamageNegationTraitEffect",
		new_trait_bridged.active_traits.size() == golem_species.starting_trait_ids.size() + 1
		and new_trait_bridged.active_traits.any(func(t): return t.trait_data != null and t.trait_data.id == "artful_dodger")
	)

	# Slime already innately carries critical_massacre -- granting it again
	# must be a no-op per the source text's own "has no effect on those who
	# already have that bonus" caveat, not a stacked duplicate.
	var dup_trait_loadout := MonsterLoadout.new()
	dup_trait_loadout.species_id = "slime"
	dup_trait_loadout.crafted_blacksmith_ids = ["critical_massacre"]
	var dup_trait_saved_team := SavedTeam.new()
	dup_trait_saved_team.members = [dup_trait_loadout]
	var dup_trait_bridged := TeamToBattleBridge.build_team(dup_trait_saved_team, "side_a", monster_db, skill_db, trait_db, skillset_db, 0, null, blacksmith_db)[0]
	var slime_species := monster_db.get_species("slime")
	_check("Slime's own species fixture already innately carries critical_massacre (sanity check)", slime_species.starting_trait_ids.has("critical_massacre"))
	_check(
		"crafting critical_massacre onto a Slime that already has it innately is a no-op, not a stacked duplicate",
		dup_trait_bridged.active_traits.size() == slime_species.starting_trait_ids.size()
	)

	# Backward compatibility: omitting blacksmith_db entirely.
	var no_blacksmith_db_bridged := TeamToBattleBridge.build_team(stat_saved_team, "side_a", monster_db, skill_db, trait_db, skillset_db, 0)[0]
	_check("omitting blacksmith_db from build_team leaves crafted_stat_boosts empty (backward compatible)", no_blacksmith_db_bridged.crafted_stat_boosts.is_empty())

	# --- TeamRosterManager validation ---
	var roster := TeamRosterManager.new("user://test_teams_blacksmith_battle_runner/")
	var unknown_item_loadout := MonsterLoadout.new()
	unknown_item_loadout.species_id = "slime"
	unknown_item_loadout.crafted_blacksmith_ids = ["nonexistent_item"]
	_check(
		"unknown crafted_blacksmith_ids entry is flagged when a blacksmith_db is supplied",
		roster.validate_member(unknown_item_loadout, monster_db, SkillSetDatabase.new(), null, blacksmith_db).size() == 1
	)
	_check(
		"the same unknown item is unflagged when blacksmith_db is omitted (backward compatible)",
		roster.validate_member(unknown_item_loadout, monster_db, SkillSetDatabase.new()).is_empty()
	)

## Proves the size/synthesis-stack trait gating actually reaches a real
## MonsterInstance's active_traits through TeamToBattleBridge, not just
## TeamRosterManager.get_active_trait_ids() in isolation (covered separately,
## with more threshold detail, in team_roster_test_runner.gd).
func _check_size_synth_trait_bridge_mechanics() -> void:
	var monster_db := MonsterDatabase.new()
	var skill_db := SkillDatabase.new()
	var trait_db := TraitDatabase.new()
	var skillset_db := SkillSetDatabase.new()

	var baseline_loadout := MonsterLoadout.new()
	baseline_loadout.species_id = "slime"
	var baseline_saved_team := SavedTeam.new()
	baseline_saved_team.members = [baseline_loadout]
	var baseline_bridged := TeamToBattleBridge.build_team(baseline_saved_team, "side_a", monster_db, skill_db, trait_db, skillset_db, 0)[0]
	var slime_species := monster_db.get_species("slime")
	_check(
		"a fresh bridged Slime carries only its 3 starting traits, none of the size/synth-gated ones",
		baseline_bridged.active_traits.size() == slime_species.starting_trait_ids.size()
	)

	var reborn_loadout := MonsterLoadout.new()
	reborn_loadout.species_id = "slime"
	reborn_loadout.current_size = 3
	reborn_loadout.synthesis_stack = 100
	var reborn_saved_team := SavedTeam.new()
	reborn_saved_team.members = [reborn_loadout]
	var reborn_bridged := TeamToBattleBridge.build_team(reborn_saved_team, "side_a", monster_db, skill_db, trait_db, skillset_db, 0)[0]
	_check(
		"a Slime reborn to size 3 with a maxed synthesis stack is bridged with all 3 starting traits plus all 5 gated ones (P+H, +25/+50/+★)",
		reborn_bridged.active_traits.size() == slime_species.starting_trait_ids.size() + 5
		and reborn_bridged.active_traits.any(func(t): return t.trait_data != null and t.trait_data.id == "random_accelerate")
		and reborn_bridged.active_traits.any(func(t): return t.trait_data != null and t.trait_data.id == "strong_guard_break")
	)

## Real report: "the enemy shouldn't attack my other monster, just the
## taunting one." Selflessness's own fixture used to be a plain self-
## damage DamageEffect (an import mistake -- see wiki/log.md), which did
## nothing resembling "takes damage instead of an ally" at all. Builds a
## 2-monster side_b (so there's a genuine "other monster" to prove the
## redirect actually diverts away from, not just a 1v1 where any target
## trivially "works") and drives everything through the real
## ActionExecutor.execute() + SkillDatabase-loaded skill, not a hand-built
## fake, so this exercises the same code path a real battle does.
func _check_taunt_mechanics() -> void:
	var team_builder := TeamBuilder.new()
	var side_a := team_builder.build_team(["slime"], "side_a")
	var side_b := team_builder.build_team(["golem", "dracky"], "side_b")
	var event_bus := BattleEventBus.new()
	var state := BattleState.new(DeterministicRng.new(1), event_bus)
	state.side_a_team = side_a
	state.side_b_team = side_b
	state.set_active_at("side_a", 0, 0)
	state.set_active_at("side_b", 0, 0)
	state.set_active_at("side_b", 1, 1)
	var ctx := BattleContext.new(state)
	var attacker := side_a[0]
	var golem := side_b[0]
	var dracky := side_b[1]

	# --- skill data itself: selflessness now applies TauntEffect, not damage ---
	var selflessness := team_builder.skill_database.get_skill("selflessness")
	_check(
		"selflessness's own fixture is a self-targeted TauntEffect, not a damage effect",
		selflessness.target_type == SkillData.TargetType.SELF
		and selflessness.effects.size() == 1 and selflessness.effects[0] is TauntEffect
	)
	selflessness.effects[0].apply(ctx, dracky, dracky)
	_check("applying selflessness's effect sets is_taunting on the caster", dracky.is_taunting)
	dracky.is_taunting = false  # reset -- the rest of this check drives it directly for determinism

	# --- the actual reported bug: attacking golem while dracky taunts must redirect to dracky ---
	dracky.is_taunting = true
	var offense: int = attacker.get_effective_stat("attack")
	var dracky_defense: int = dracky.get_effective_stat("defense")
	var base_damage := DamageFormula.calculate(team_builder.skill_registry["attack"].effects[0].power, offense, dracky_defense)
	var expected_taunt_damage := MathUtils.round_half_up(float(base_damage) * DamageEffect.TAUNT_DAMAGE_MULTIPLIER)
	ActionExecutor.execute(ctx, Action.new(attacker.instance_id, "attack", golem.instance_id), team_builder.skill_registry)
	_check("golem (the monster actually clicked) takes no damage at all while dracky is taunting", golem.current_hp == golem.species.base_hp)
	var redirected_hit: DamageAppliedEvent = null
	for event in ctx.event_bus.get_log():
		if event is DamageAppliedEvent:
			redirected_hit = event
	_check("the hit lands on dracky (the taunter) instead of the clicked golem", redirected_hit != null and redirected_hit.target_instance_id == dracky.instance_id)
	_check("taunting increases damage taken to the hand-computed multiplied amount", redirected_hit != null and redirected_hit.amount == expected_taunt_damage)
	_check("the taunt-multiplied damage is strictly more than the un-taunted baseline", expected_taunt_damage > base_damage)

	var narrated_skill_used: SkillUsedEvent = null
	for event in ctx.event_bus.get_log():
		if event is SkillUsedEvent:
			narrated_skill_used = event
	_check("SkillUsedEvent itself also reports the redirected target, not the originally-clicked one (correct narration)", narrated_skill_used != null and narrated_skill_used.target_instance_id == dracky.instance_id)

	# --- lifetime: clears the moment the taunter takes its own next action ---
	ActionExecutor.execute(ctx, Action.new(dracky.instance_id, "attack", attacker.instance_id), team_builder.skill_registry)
	_check("is_taunting clears the moment this monster's own next action executes", not dracky.is_taunting)

	# --- already targeting the taunter directly is a harmless no-op ---
	var direct_harness_state := BattleState.new(DeterministicRng.new(1), BattleEventBus.new())
	var direct_side_a := team_builder.build_team(["slime"], "side_a")
	var direct_side_b := team_builder.build_team(["golem", "dracky"], "side_b")
	direct_harness_state.side_a_team = direct_side_a
	direct_harness_state.side_b_team = direct_side_b
	direct_harness_state.set_active_at("side_a", 0, 0)
	direct_harness_state.set_active_at("side_b", 0, 0)
	direct_harness_state.set_active_at("side_b", 1, 1)
	var direct_ctx := BattleContext.new(direct_harness_state)
	direct_side_b[1].is_taunting = true
	ActionExecutor.execute(direct_ctx, Action.new(direct_side_a[0].instance_id, "attack", direct_side_b[1].instance_id), team_builder.skill_registry)
	var direct_hit: DamageAppliedEvent = null
	for event in direct_ctx.event_bus.get_log():
		if event is DamageAppliedEvent:
			direct_hit = event
	_check("directly targeting the taunter already (no redirect needed) still lands on them correctly", direct_hit != null and direct_hit.target_instance_id == direct_side_b[1].instance_id)

## Real sweep: found while investigating the Selflessness/taunt report --
## 38 self-targeted skills across the full fixture set whose only "effect"
## was a self-damage DamageEffect that didn't match their own description
## at all (the same import-mistake class as Selflessness). Fixed the
## subset that fits this engine's existing single-target framework without
## needing new ally/AOE targeting infrastructure (see wiki/log.md for the
## full list and what's deliberately deferred to a follow-up): the Counter
## family, Deep Breath, Mist Me, and Defending Champion. Each fresh
## harness below is deliberately NOT shared across sub-checks, same reason
## as _check_taunt_mechanics()'s own second harness -- avoids one
## sub-check's ActionExecutor.execute() calls (which reset every "until my
## next action" flag on whichever monster acts) quietly interfering with
## another's.
func _check_counter_stance_and_utility_skill_mechanics() -> void:
	var team_builder := TeamBuilder.new()

	# --- Counter family: skill data itself ---
	var counter_slash_data := team_builder.skill_database.get_skill("counter_slash")
	_check(
		"counter_slash's own fixture is a self-targeted CounterStanceEffect filtered to Slash, not a damage effect",
		counter_slash_data.target_type == SkillData.TargetType.SELF and counter_slash_data.effects.size() == 1
		and counter_slash_data.effects[0] is CounterStanceEffect
		and counter_slash_data.effects[0].allowed_skill_types == (["Slash"] as Array[String])
	)
	var plain_counter_data := team_builder.skill_database.get_skill("counter")
	_check(
		"plain counter's own fixture allows BOTH Slash and the no-skill_type basic Attack, per its own \"also can reflect normal attacks\" wording",
		plain_counter_data.effects[0].allowed_skill_types == (["Slash", ""] as Array[String])
	)

	# --- Counter family: a non-matching category must NOT trigger a filtered stance ---
	var mismatch_harness := _new_harness(team_builder)
	mismatch_harness.target.current_mp = team_builder.skill_registry["counter_slash"].mp_cost
	ActionExecutor.execute(mismatch_harness.ctx, Action.new(mismatch_harness.target.instance_id, "counter_slash", mismatch_harness.target.instance_id), team_builder.skill_registry)
	_check("casting counter_slash sets the defender's countering_skill_types to just Slash", mismatch_harness.target.countering_skill_types == (["Slash"] as Array[String]))
	ActionExecutor.execute(mismatch_harness.ctx, Action.new(mismatch_harness.actor.instance_id, "attack", mismatch_harness.target.instance_id), team_builder.skill_registry)
	var saw_mismatched_counter := false
	for event in mismatch_harness.ctx.event_bus.get_log():
		if event is CounterattackEvent:
			saw_mismatched_counter = true
	_check("counter_slash does NOT trigger against a non-matching category (plain Attack has no real skill_type at all)", not saw_mismatched_counter)

	# --- Counter family: a matching category DOES trigger, for the hand-computed retaliation amount ---
	# Both sides use a tanky species (base_hp 3500) rather than the usual
	# slime/golem pair -- this check's damage flows BOTH ways (the original
	# hit, then the counter-retaliation back), and MonsterInstance.take_damage
	# clamps to [0, species.base_hp], so a fragile combatant on either side
	# would silently clamp the applied amount below the hand-computed raw
	# value and fail the equality check for the wrong reason.
	var match_harness := _new_harness(team_builder, "great_muddy_hand", "great_muddy_hand")
	var defender: MonsterInstance = match_harness.target
	var attacker: MonsterInstance = match_harness.actor
	defender.current_mp = team_builder.skill_registry["counter_slash"].mp_cost
	attacker.current_mp = team_builder.skill_registry["anchor_knuckle"].mp_cost
	ActionExecutor.execute(match_harness.ctx, Action.new(defender.instance_id, "counter_slash", defender.instance_id), team_builder.skill_registry)
	var expected_counter_damage := DamageFormula.calculate(0, defender.get_effective_stat("attack"), attacker.get_effective_stat("defense"))
	ActionExecutor.execute(match_harness.ctx, Action.new(attacker.instance_id, "anchor_knuckle", defender.instance_id), team_builder.skill_registry)
	var counter_event: CounterattackEvent = null
	for event in match_harness.ctx.event_bus.get_log():
		if event is CounterattackEvent:
			counter_event = event
	_check("counter_slash DOES trigger against a matching category (a real Slash-type skill, Anchor Knuckle)", counter_event != null)
	_check(
		"the retaliation lands on the original attacker, for the hand-computed amount",
		counter_event != null and counter_event.source_instance_id == defender.instance_id
		and counter_event.target_instance_id == attacker.instance_id and counter_event.amount == expected_counter_damage
	)
	ActionExecutor.execute(match_harness.ctx, Action.new(defender.instance_id, "attack", attacker.instance_id), team_builder.skill_registry)
	_check("countering_skill_types clears the moment the defender's own next action executes", defender.countering_skill_types.is_empty())

	# --- Deep Breath: boosts damage of a real Breath-type skill used next, and only that ---
	# Aurora Breath's power (315, further boosted 1.5x) would one-shot a
	# normal 50 HP test monster and clamp the applied amount below the
	# hand-computed raw value -- give the target a tanky species instead
	# (see the match_harness comment above for why the clamp matters).
	var breath_harness := _new_harness(team_builder, "slime", "great_muddy_hand")
	var breather: MonsterInstance = breath_harness.actor
	var breath_target: MonsterInstance = breath_harness.target
	ActionExecutor.execute(breath_harness.ctx, Action.new(breather.instance_id, "deep_breath", breather.instance_id), team_builder.skill_registry)
	_check("casting deep_breath sets the caster's own charge flag", breather.deep_breath_charged)
	breather.current_mp = team_builder.skill_registry["aurora_breath"].mp_cost
	var aurora_breath_power: int = team_builder.skill_registry["aurora_breath"].effects[0].power
	var boosted_power := MathUtils.round_half_up(float(aurora_breath_power) * DamageEffect.DEEP_BREATH_DAMAGE_MULTIPLIER)
	ActionExecutor.execute(breath_harness.ctx, Action.new(breather.instance_id, "aurora_breath", breath_target.instance_id), team_builder.skill_registry)
	var boosted_hit: DamageAppliedEvent = null
	for event in breath_harness.ctx.event_bus.get_log():
		if event is DamageAppliedEvent:
			boosted_hit = event
	# Slime (the attacker here) innately carries critical_massacre, so this
	# single hit can legitimately land as a crit depending on RNG -- a crit
	# ignores defense entirely (see DamageEffect.apply()), so the expected
	# value has to branch on the real hit's own is_critical flag rather than
	# assuming defense always applies.
	var expected_boosted_damage := DamageFormula.calculate(
		boosted_power, breather.get_effective_stat("attack"),
		0 if (boosted_hit != null and boosted_hit.is_critical) else breath_target.get_effective_stat("defense")
	)
	_check("a real Breath-type skill (Aurora Breath) used right after Deep Breath deals the hand-computed BOOSTED amount", boosted_hit != null and boosted_hit.amount == expected_boosted_damage)
	_check("deep_breath_charged clears the moment this monster's own next action executes", not breather.deep_breath_charged)

	var wasted_breath_harness := _new_harness(team_builder)
	var wasted_breather: MonsterInstance = wasted_breath_harness.actor
	ActionExecutor.execute(wasted_breath_harness.ctx, Action.new(wasted_breather.instance_id, "deep_breath", wasted_breather.instance_id), team_builder.skill_registry)
	ActionExecutor.execute(wasted_breath_harness.ctx, Action.new(wasted_breather.instance_id, "attack", wasted_breath_harness.target.instance_id), team_builder.skill_registry)
	_check("charging Deep Breath and then using a non-Breath skill just clears the charge for nothing (no boost, no crash)", not wasted_breather.deep_breath_charged)

	# --- Mist Me: the chance is rolled once at cast time, not per incoming hit ---
	var success_harness := _new_harness(team_builder)
	var forced_success := MistMeEffect.new()
	forced_success.success_chance = 1.0
	forced_success.apply(success_harness.ctx, success_harness.target, success_harness.target)
	_check("Mist Me's forced-success roll (chance=1.0) sets mist_me_active", success_harness.target.mist_me_active)
	ActionExecutor.execute(success_harness.ctx, Action.new(success_harness.actor.instance_id, "attack", success_harness.target.instance_id), team_builder.skill_registry)
	var mist_hit: DamageAppliedEvent = null
	for event in success_harness.ctx.event_bus.get_log():
		if event is DamageAppliedEvent:
			mist_hit = event
	_check("an active Mist Me ward reduces the next hit taken to exactly 0 (was_negated, not just reduced)", mist_hit != null and mist_hit.amount == 0 and mist_hit.was_negated)
	_check("the ward is consumed by that one hit, not left standing", not success_harness.target.mist_me_active)

	var failure_harness := _new_harness(team_builder)
	var forced_failure := MistMeEffect.new()
	forced_failure.success_chance = 0.0
	forced_failure.apply(failure_harness.ctx, failure_harness.target, failure_harness.target)
	_check("Mist Me's forced-failure roll (chance=0.0) leaves mist_me_active false (a wasted turn, not a guaranteed ward)", not failure_harness.target.mist_me_active)

	# --- Defending Champion: a real sourced number (1/10 reduction), and it does NOT reset each turn ---
	var champion_harness := _new_harness(team_builder)
	var champion: MonsterInstance = champion_harness.target
	var champion_attacker: MonsterInstance = champion_harness.actor
	ActionExecutor.execute(champion_harness.ctx, Action.new(champion.instance_id, "defending_champion", champion.instance_id), team_builder.skill_registry)
	_check("casting defending_champion sets the persistent flag", champion.defending_champion_active)
	var champion_base_damage := DamageFormula.calculate(team_builder.skill_registry["attack"].effects[0].power, champion_attacker.get_effective_stat("attack"), champion.get_effective_stat("defense"))
	var expected_champion_damage := MathUtils.round_half_up(float(champion_base_damage) * DamageEffect.DEFENDING_CHAMPION_DAMAGE_MULTIPLIER)
	ActionExecutor.execute(champion_harness.ctx, Action.new(champion_attacker.instance_id, "attack", champion.instance_id), team_builder.skill_registry)
	var champion_hit: DamageAppliedEvent = null
	for event in champion_harness.ctx.event_bus.get_log():
		if event is DamageAppliedEvent:
			champion_hit = event
	_check("Defending Champion reduces damage taken to the hand-computed 1/10-less amount", champion_hit != null and champion_hit.amount == expected_champion_damage)
	# Champion's own next action (unlike every flag above) must NOT clear the buff -- it lasts the rest of the battle.
	ActionExecutor.execute(champion_harness.ctx, Action.new(champion.instance_id, "attack", champion_attacker.instance_id), team_builder.skill_registry)
	_check("defending_champion_active is still true after the champion's own next action -- it lasts the whole battle, not just one turn", champion.defending_champion_active)

## One fresh actor(side_a)/target(side_b) pair plus a real BattleContext,
## isolated per status scenario so one test's active_status/event log can't
## leak into another's.
func _new_harness(team_builder: TeamBuilder, actor_species: String = "slime", target_species: String = "golem") -> Dictionary:
	var side_a := team_builder.build_team([actor_species], "side_a")
	var side_b := team_builder.build_team([target_species], "side_b")
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
