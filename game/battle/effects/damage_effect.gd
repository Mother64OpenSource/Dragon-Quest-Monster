class_name DamageEffect
extends SkillEffect

enum Category { PHYSICAL, MAGIC }

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

	for _hit in range(hit_count):
		if target.is_fainted():
			break
		var offense := user.get_effective_stat(offense_stat_name)
		var defense := target.get_effective_stat(defense_stat_name)
		var raw_damage := DamageFormula.calculate(power, offense, defense)
		var final_damage := _run_damage_hooks(ctx, user, target, raw_damage)
		var applied := target.take_damage(final_damage)
		ctx.event_bus.emit_event(
			DamageAppliedEvent.new(user.instance_id, target.instance_id, applied, target.current_hp),
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
	return maxi(0, damage)
