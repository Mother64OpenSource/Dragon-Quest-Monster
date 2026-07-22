class_name ActionExecutor
extends RefCounted

## Executes one resolved Action: fizzle checks (invalid/fainted target,
## insufficient MP), an accuracy roll, then each SkillEffect in array order.
## Trait "before damage" hooks are invoked inside DamageEffect itself
## (per-hit), not here — that's the only place a concrete damage number
## exists to modify.
static func execute(ctx: BattleContext, action: Action, skill_lookup: Dictionary) -> void:
	var actor := ctx.state.get_monster_by_instance_id(action.actor_instance_id)
	if actor == null or actor.is_fainted():
		return

	var skill: SkillData = skill_lookup.get(action.skill_id)
	if skill == null:
		push_error("Unknown skill_id in action: %s" % action.skill_id)
		return

	var target := ctx.state.get_monster_by_instance_id(action.target_instance_id)
	var target_invalid := skill.target_type == SkillData.TargetType.SINGLE_ENEMY \
		and (target == null or target.is_fainted())

	if target_invalid or actor.current_mp < skill.mp_cost:
		var fizzled_event := SkillUsedEvent.new(actor.instance_id, action.skill_id, action.target_instance_id)
		fizzled_event.fizzled = true
		ctx.event_bus.emit_event(fizzled_event, ctx.state.turn_number)
		return

	actor.current_mp -= skill.mp_cost

	var missed := not ctx.rng.chance(skill.accuracy)
	var used_event := SkillUsedEvent.new(actor.instance_id, action.skill_id, action.target_instance_id)
	used_event.missed = missed
	ctx.event_bus.emit_event(used_event, ctx.state.turn_number)
	if missed:
		return

	for effect in skill.effects:
		effect.apply(ctx, actor, target)
		FaintHandler.handle_if_fainted(ctx, actor)
		if target != null:
			FaintHandler.handle_if_fainted(ctx, target)
			if target.is_fainted():
				break
