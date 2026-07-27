class_name StatModEffect
extends SkillEffect

@export var stat_name: String = "attack"
@export var stages: int = 1
@export var chance: float = 1.0
@export var target_self: bool = true
## Mirrors the parent SkillData.element (see its own doc comment), set by
## SkillLoader at load time -- lets a Ward/crafty_X trait recognize which
## stat-debuff spell this is (e.g. "Sag", "Sap", "Decelerate") the same way
## DamageEffect.element already lets one recognize an elemental attack.
@export var element: String = ""

func apply(ctx: BattleContext, user: MonsterInstance, target: MonsterInstance) -> void:
	var recipient := user if target_self else target
	if recipient.is_fainted():
		return
	var effective_chance := chance
	for trait_effect in user.active_traits:
		effective_chance *= trait_effect.get_stat_mod_infliction_multiplier(element)
	for trait_effect in recipient.active_traits:
		effective_chance *= trait_effect.get_stat_mod_resistance_multiplier(element)
	if not ctx.rng.chance(effective_chance):
		return
	var applied_delta := recipient.apply_stat_stage(stat_name, stages)
	var new_stage := recipient.stat_stages.get_stage(stat_name)
	ctx.event_bus.emit_event(
		StatChangedEvent.new(recipient.instance_id, stat_name, applied_delta, new_stage),
		ctx.state.turn_number
	)
