class_name DamageEffect
extends SkillEffect

enum Category { PHYSICAL, MAGIC }

## No sourced real value exists for this -- a documented placeholder, same
## honesty convention as every other invented numeric constant in this
## project (see wiki/log.md).
const BASE_CRIT_CHANCE := 0.0625
## Also a documented placeholder -- see wiki/log.md.
const TENSION_DAMAGE_PERCENT_PER_LEVEL := 0.25
## A real, well-established DQ mechanic (unlike this file's other invented
## placeholder constants) -- the classic "Defend" command roughly halves
## incoming damage until the defender's own next turn.
const DEFEND_DAMAGE_MULTIPLIER := 0.5

@export var category: Category = Category.PHYSICAL
@export var power: int = 0
@export var min_hits: int = 1
@export var max_hits: int = 1

func apply(ctx: BattleContext, user: MonsterInstance, target: MonsterInstance) -> void:
	var hit_count := min_hits
	if max_hits > min_hits:
		hit_count = ctx.rng.randi_range(min_hits, max_hits)

	var offense_stat_name := "attack" if category == Category.PHYSICAL else "wisdom"
	var defense_stat_name := "defense" if category == Category.PHYSICAL else "wisdom"

	# Snapshotted once per action, not re-read per hit -- real DQM tension is
	# spent once per attack (even a multi-hit one), not re-consumed hit by
	# hit, and every hit of a multi-hit skill should get the same boost.
	var tension_snapshot := user.tension_level

	for _hit in range(hit_count):
		if target.is_fainted():
			break
		var offense := user.get_effective_stat(offense_stat_name)
		var defense := target.get_effective_stat(defense_stat_name)
		var is_critical := _roll_critical(ctx, user, target)
		# The one real, well-documented DQM crit property (already researched
		# in wiki/log.md): a critical hit ignores the target's defense
		# entirely, honestly adapted into this engine's own placeholder
		# formula rather than grafting in the real formula's fully different
		# shape (which has no "power" term at all).
		var raw_damage := DamageFormula.calculate(power, offense, 0 if is_critical else defense)
		if tension_snapshot > 0:
			raw_damage = MathUtils.round_half_up(float(raw_damage) * (1.0 + TENSION_DAMAGE_PERCENT_PER_LEVEL * tension_snapshot))
		var final_damage := _run_damage_hooks(ctx, user, target, raw_damage)
		var was_negated := raw_damage > 0 and final_damage == 0
		var applied := target.take_damage(final_damage)
		var event := DamageAppliedEvent.new(user.instance_id, target.instance_id, applied, target.current_hp)
		event.is_critical = is_critical
		event.was_negated = was_negated
		ctx.event_bus.emit_event(event, ctx.state.turn_number)
		# A dodged/fully-blocked crit was never actually "taken" -- Heat Up
		# shouldn't build tension off a hit that didn't land.
		if is_critical and final_damage > 0:
			for trait_effect in target.active_traits:
				trait_effect.on_critical_hit_taken(ctx, target, user)
		_wake_if_sleeping(ctx, target)

	if tension_snapshot > 0:
		user.tension_level = 0

## Crit-chance bonuses from the attacker's own traits stack multiplicatively
## (matches "doubles the chance" wording better than an additive bonus),
## then the target gets a veto (Full Satisfaction Guard) before a crit is
## ever finalized.
func _roll_critical(ctx: BattleContext, user: MonsterInstance, target: MonsterInstance) -> bool:
	var chance := BASE_CRIT_CHANCE
	for trait_effect in user.active_traits:
		chance *= trait_effect.get_crit_chance_multiplier(user, category)
	if not ctx.rng.chance(chance):
		return false
	for trait_effect in target.active_traits:
		if trait_effect.blocks_critical_hits():
			return false
	return true

## Sleep: "cannot act until awoken by an attack" -- taking any damage clears
## it immediately rather than waiting out its normal per-turn wake chance.
## Reuses StatusTickEvent(expired=true) for narration instead of a new event
## type, since "the status just ended" is exactly what that event already
## communicates, whatever the reason.
func _wake_if_sleeping(ctx: BattleContext, target: MonsterInstance) -> void:
	if target.is_fainted() or target.active_status == null or not target.active_status.status_data.wakes_on_damage:
		return
	var status_id := target.active_status.status_data.id
	target.active_status = null
	ctx.event_bus.emit_event(
		StatusTickEvent.new(target.instance_id, status_id, 0, target.current_hp, true),
		ctx.state.turn_number
	)

## Each hit goes through the user's on_before_damage_dealt hooks then the
## target's on_before_damage_taken hooks — per-hit, not per-action, since
## multi-hit skills roll damage independently for each hit.
func _run_damage_hooks(ctx: BattleContext, user: MonsterInstance, target: MonsterInstance, raw_damage: int) -> int:
	var damage := raw_damage
	for trait_effect in user.active_traits:
		damage = trait_effect.on_before_damage_dealt(ctx, user, target, damage)
	for trait_effect in target.active_traits:
		damage = trait_effect.on_before_damage_taken(ctx, target, user, damage)
	if target.is_defending:
		damage = MathUtils.round_half_up(float(damage) * DEFEND_DAMAGE_MULTIPLIER)
	return maxi(0, damage)
