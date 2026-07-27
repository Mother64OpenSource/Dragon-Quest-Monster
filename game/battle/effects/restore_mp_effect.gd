class_name RestoreMpEffect
extends SkillEffect

## Mirrors HealEffect's own shape (a flat power plus an optional
## percent-of-max top-up), but restores MP instead of HP (Magic
## Multiplier, Sonata of Serenity). target_self mirrors HealEffect's own
## default and this engine's established no-ally-targeting simplification.

@export var power: int = 0
@export var percent_max_mp: float = 0.0
@export var target_self: bool = true

func apply(ctx: BattleContext, user: MonsterInstance, target: MonsterInstance) -> void:
	var recipient := user if target_self else target
	if recipient.is_fainted():
		return
	var amount := power
	if percent_max_mp > 0.0:
		amount += MathUtils.percent_of(recipient.species.base_mp, percent_max_mp)
	var before_mp := recipient.current_mp
	recipient.current_mp = mini(recipient.current_mp + amount, recipient.species.base_mp)
	var applied := recipient.current_mp - before_mp
	ctx.event_bus.emit_event(
		MpRestoredEvent.new(user.instance_id, recipient.instance_id, applied, recipient.current_mp),
		ctx.state.turn_number
	)
