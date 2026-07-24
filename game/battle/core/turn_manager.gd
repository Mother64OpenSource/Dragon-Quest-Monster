class_name TurnManager
extends RefCounted

## Drives exactly one full turn: collect actions in fixed canonical order
## (side_a slot0, side_a slot1, side_b slot0, side_b slot1) -> resolve order
## -> execute -> end-of-turn processing -> victory check.
static func run_turn(ctx: BattleContext, action_providers: Dictionary, skill_lookup: Dictionary) -> void:
	var state := ctx.state
	state.turn_number += 1
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

	var ordered := ActionResolver.resolve_order(submitted, state, skill_lookup)

	for action in ordered:
		var actor := state.get_monster_by_instance_id(action.actor_instance_id)
		if actor == null or actor.is_fainted():
			continue
		ActionExecutor.execute(ctx, action, skill_lookup)
		if VictoryChecker.check(ctx):
			return

	EndOfTurnProcessor.process(ctx)
	if VictoryChecker.check(ctx):
		return

	ctx.event_bus.emit_event(TurnEndedEvent.new(), state.turn_number)
