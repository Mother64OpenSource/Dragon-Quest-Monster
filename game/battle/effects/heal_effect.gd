class_name HealEffect
extends SkillEffect

@export var power: int = 0
@export var percent_max_hp: float = 0.0
@export var target_self: bool = true

func apply(ctx: BattleContext, user: MonsterInstance, target: MonsterInstance) -> void:
	var recipient := user if target_self else target
	if recipient.is_fainted():
		return
	var amount := power
	if percent_max_hp > 0.0:
		amount += MathUtils.percent_of(recipient.species.base_hp, percent_max_hp)
	var applied := recipient.heal(amount)
	ctx.event_bus.emit_event(
		HealingAppliedEvent.new(user.instance_id, recipient.instance_id, applied, recipient.current_hp),
		ctx.state.turn_number
	)
