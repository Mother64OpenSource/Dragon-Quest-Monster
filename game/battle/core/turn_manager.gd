class_name TurnManager
extends RefCounted

## Drives exactly one full turn: collect actions in fixed canonical order
## (side_a slot0, side_a slot1, side_b slot0, side_b slot1) -> resolve order
## -> execute -> end-of-turn processing -> victory check.
static func run_turn(ctx: BattleContext, action_providers: Dictionary, skill_lookup: Dictionary) -> void:
	var state := ctx.state
	state.turn_number += 1
	state.acted_this_turn_instance_ids.clear()
	ctx.event_bus.emit_event(TurnStartedEvent.new(), state.turn_number)
	StartOfTurnProcessor.process(ctx)

	var submitted: Array[Action] = []
	var submission_index := 0
	for side in ["side_a", "side_b"]:
		var provider: ActionProvider = action_providers[side]
		var active_slot_count := state.get_active_slot_count(side)
		# A multi-slot monster occupies more than one raw slot index -- only
		# ask its provider for one action, at the first (lowest) slot it
		# occupies, or it would act once per slot it spans.
		var acted_instance_ids := {}
		for slot in range(active_slot_count):
			var monster := state.get_monster_at(side, slot)
			if monster == null or monster.is_fainted():
				continue
			if acted_instance_ids.has(monster.instance_id):
				continue
			acted_instance_ids[monster.instance_id] = true
			var action := provider.get_action(state, side, slot)
			if action == null:
				continue
			action.submission_index = submission_index
			submission_index += 1
			submitted.append(action)

	# Shuffle/Unnatural Order affect the round AFTER the one they're cast in
	# (see BattleState.shuffle_next_round's own doc comment) -- consumed
	# here, once, at the point this round's order is actually built. If
	# somehow both got set in the same prior round (two different monsters
	# each casting one), Shuffle wins arbitrarily but deterministically.
	var ordered: Array[Action]
	if state.shuffle_next_round:
		state.shuffle_next_round = false
		state.reverse_next_round = false
		ordered = ActionResolver.shuffle_actions(submitted, state)
	elif state.reverse_next_round:
		state.reverse_next_round = false
		ordered = ActionResolver.resolve_order(submitted, state, skill_lookup)
		ordered.reverse()
	else:
		ordered = ActionResolver.resolve_order(submitted, state, skill_lookup)

	for action in ordered:
		var actor := state.get_monster_by_instance_id(action.actor_instance_id)
		if actor == null or actor.is_fainted():
			continue
		state.acted_this_turn_instance_ids[actor.instance_id] = true
		# Hit Squad et al: extra full repeats of the SAME queued action, each
		# its own independent execute() call (own accuracy roll, MP cost,
		# crit roll, own SkillUsedEvent -- not just extra hits within one
		# skill's own effects, which is DamageEffect.min_hits/max_hits, a
		# separate mechanic). Since each repeat emits a real SkillUsedEvent,
		# BattleSideView's existing per-event animation loop plays the
		# attack lunge once per repeat for free -- no separate visual code
		# needed for "looks like it's attacking multiple times."
		var attack_count := 1
		for trait_effect in actor.active_traits:
			attack_count += trait_effect.get_extra_attack_count()
		for repeat in range(attack_count):
			if actor.is_fainted():
				break
			ActionExecutor.execute(ctx, action, skill_lookup)
			if VictoryChecker.check(ctx):
				return

	EndOfTurnProcessor.process(ctx)
	if VictoryChecker.check(ctx):
		return

	ctx.event_bus.emit_event(TurnEndedEvent.new(), state.turn_number)
