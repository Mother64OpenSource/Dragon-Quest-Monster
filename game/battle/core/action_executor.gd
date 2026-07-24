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

	if action.action_type == Action.Type.DEFEND:
		actor.is_defending = true
		ctx.event_bus.emit_event(DefendEvent.new(actor.instance_id), ctx.state.turn_number)
		return
	# Defend protects until this monster's own next action, whatever that
	# turns out to be -- so taking any OTHER action (even one later
	# prevented/fizzled/missed; a turn boundary still passed) clears it
	# here, before any of the early-return paths below.
	actor.is_defending = false

	var skill: SkillData = skill_lookup.get(action.skill_id)
	if skill == null:
		push_error("Unknown skill_id in action: %s" % action.skill_id)
		return

	var status_data := actor.active_status.status_data if actor.active_status != null else null
	if status_data != null:
		# A full-body condition (Sleep/Paralysis/Immobilize/Confusion) rolls a
		# chance each turn to prevent acting at all, regardless of what skill
		# was queued -- checked before target/MP validity since the monster
		# never gets as far as attempting the move.
		if status_data.skip_turn_chance > 0.0 and ctx.rng.chance(status_data.skip_turn_chance):
			var prevented_event := SkillUsedEvent.new(actor.instance_id, action.skill_id, action.target_instance_id)
			prevented_event.prevented_by_status = status_data.id
			ctx.event_bus.emit_event(prevented_event, ctx.state.turn_number)
			return
		# A category seal (Silence blocks "magic", Gobstop/Skill Sealed blocks
		# every non-Attack skill) only stops the specific move queued -- a
		# basic Attack always stays usable, matching the real games.
		if _is_blocked_by_category(status_data, skill):
			var blocked_event := SkillUsedEvent.new(actor.instance_id, action.skill_id, action.target_instance_id)
			blocked_event.prevented_by_status = status_data.id
			ctx.event_bus.emit_event(blocked_event, ctx.state.turn_number)
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

	var missed := not ctx.rng.chance(_effective_accuracy(status_data, skill, actor))
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

## "skill" (Gobstop/Skill Sealed) blocks everything except the universal
## "attack" id -- a category match alone can't express this, since Attack
## and every other physical skill share SkillData.Category.PHYSICAL.
## "magic" (Silence/Fizzled) is a real category match: it blocks every
## MAGIC-category skill and nothing else.
static func _is_blocked_by_category(status_data: StatusData, skill: SkillData) -> bool:
	match status_data.blocked_skill_category:
		"skill":
			return skill.id != "attack"
		"magic":
			return skill.category == SkillData.Category.MAGIC
		_:
			return false

## Dazzle only degrades PHYSICAL accuracy ("much more likely to miss with
## physical attacks") -- spells/status moves roll at their normal chance.
## A pure function (no RNG) so its exact multiplier logic is directly
## unit-testable rather than only observable through many probabilistic
## accuracy-roll trials. `actor` is optional (default null) so the existing
## direct-call test sites (battle_test_runner.gd's dazzle checks) that pass
## only 2 args keep compiling unchanged -- only the real execute() call site
## has an actor to pass, and only it needs Hopeful Hitter's accuracy trade-off.
static func _effective_accuracy(status_data: StatusData, skill: SkillData, actor: MonsterInstance = null) -> float:
	var accuracy := skill.accuracy
	if status_data != null and status_data.accuracy_multiplier != 1.0 and skill.category == SkillData.Category.PHYSICAL:
		accuracy *= status_data.accuracy_multiplier
	if actor != null:
		for trait_effect in actor.active_traits:
			accuracy *= trait_effect.get_accuracy_multiplier()
	return accuracy
