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
## Selflessness's own description says only "significantly increases
## damage taken," with no real sourced number -- a documented placeholder,
## same honesty convention as this file's other invented constants.
const TAUNT_DAMAGE_MULTIPLIER := 1.5

@export var category: Category = Category.PHYSICAL
@export var power: int = 0
@export var min_hits: int = 1
@export var max_hits: int = 1
## Mirrors the parent SkillData.element (see its own doc comment) -- set by
## SkillLoader at load time. Empty for non-elemental damage (plain Attack).
@export var element: String = ""
## Mirrors the parent SkillData.skill_type (see its own doc comment) -- set
## by SkillLoader at load time.
@export var skill_type: String = ""

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
	# Same once-per-action timing as tension_snapshot itself (Dust of the
	# Clan's own chance roll only fires once per action, not once per hit).
	var tension_percent := TENSION_DAMAGE_PERCENT_PER_LEVEL
	if tension_snapshot > 0:
		for trait_effect in user.active_traits:
			tension_percent *= trait_effect.get_tension_burn_multiplier(ctx)

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
			raw_damage = MathUtils.round_half_up(float(raw_damage) * (1.0 + tension_percent * tension_snapshot))
		var final_damage := _run_damage_hooks(ctx, user, target, raw_damage)
		var was_negated := raw_damage > 0 and final_damage == 0
		if final_damage >= target.current_hp:
			for trait_effect in target.active_traits:
				if trait_effect.survives_lethal_hit(ctx, target):
					final_damage = target.current_hp - 1
					break
		var applied := target.take_damage(final_damage)
		var event := DamageAppliedEvent.new(user.instance_id, target.instance_id, applied, target.current_hp)
		event.is_critical = is_critical
		event.was_negated = was_negated
		ctx.event_bus.emit_event(event, ctx.state.turn_number)
		if applied > 0:
			_apply_weapon_lifesteal(ctx, user, applied)
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
	var weapon := user.equipped_weapon
	if weapon != null and (weapon.crit_chance_category_filter == -1 or weapon.crit_chance_category_filter == category):
		chance *= weapon.crit_chance_multiplier
	if not ctx.rng.chance(chance):
		return false
	for trait_effect in target.active_traits:
		if trait_effect.blocks_critical_hits():
			return false
	return true

## Miracle Sword et al.'s "Restores HP." -- heals the wielder a percentage of
## the damage that actually landed, per hit (a multi-hit skill heals once
## per connecting hit, matching how the damage itself is rolled per hit).
func _apply_weapon_lifesteal(ctx: BattleContext, user: MonsterInstance, damage_dealt: int) -> void:
	var weapon := user.equipped_weapon
	if weapon == null or weapon.lifesteal_percent <= 0.0 or user.is_fainted():
		return
	var amount := MathUtils.round_half_up(float(damage_dealt) * weapon.lifesteal_percent)
	var applied := user.heal(amount)
	ctx.event_bus.emit_event(
		HealingAppliedEvent.new(user.instance_id, user.instance_id, applied, user.current_hp),
		ctx.state.turn_number
	)

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

## Each hit goes through the weapon's own damage bonus, then the user's
## on_before_damage_dealt hooks, then the target's on_before_damage_taken
## hooks — per-hit, not per-action, since multi-hit skills roll damage
## independently for each hit.
func _run_damage_hooks(ctx: BattleContext, user: MonsterInstance, target: MonsterInstance, raw_damage: int) -> int:
	var damage := _apply_weapon_damage_bonus(user.equipped_weapon, target, raw_damage)
	for trait_effect in user.active_traits:
		damage = trait_effect.on_before_damage_dealt(ctx, user, target, damage, element)
		damage = MathUtils.round_half_up(float(damage) * trait_effect.get_skill_type_damage_multiplier(skill_type))
	for trait_effect in target.active_traits:
		damage = trait_effect.on_before_damage_taken(ctx, target, user, damage, element)
	if target.is_defending:
		damage = MathUtils.round_half_up(float(damage) * DEFEND_DAMAGE_MULTIPLIER)
	if target.is_taunting:
		damage = MathUtils.round_half_up(float(damage) * TAUNT_DAMAGE_MULTIPLIER)
	return maxi(0, damage)

## WeaponData.bonus_vs_families is matched case-insensitively against the
## target's species.family (fixture casing isn't fully consistent -- see
## wiki/log.md), applied as a multiplier; bonus_vs_metal_body_flat checks
## the same metal-body trait cluster BonusDamageVsMetalBodyTraitEffect
## already checks (Metal Slime is species family "Slime" but carries a
## metal_body trait, so this can't be a species.family check).
func _apply_weapon_damage_bonus(weapon: WeaponData, target: MonsterInstance, raw_damage: int) -> int:
	if weapon == null:
		return raw_damage
	var damage := raw_damage
	if not weapon.bonus_vs_families.is_empty():
		var target_family := target.species.family.to_lower()
		for family in weapon.bonus_vs_families:
			if family.to_lower() == target_family:
				damage = MathUtils.round_half_up(float(damage) * weapon.bonus_damage_multiplier)
				break
	if weapon.bonus_vs_metal_body_flat != 0:
		for trait_effect in target.active_traits:
			if trait_effect.trait_data != null and BonusDamageVsMetalBodyTraitEffect.METAL_BODY_TRAIT_IDS.has(trait_effect.trait_data.id):
				damage += weapon.bonus_vs_metal_body_flat
				break
	return damage
