class_name MpDrainOnAttackTraitEffect
extends TraitEffect

## Drain Magic Attack: the offense-side sibling of Take Magic
## (MpDrainRetaliationTraitEffect) -- chance to drain MP from whoever the
## owner directly attacks, absorbed into the owner's own MP. Same
## capped-both-ways math (never drains more than the target actually has,
## never overheals the owner past its own max) and the same documented
## placeholder percentage, since no sourced real value exists for either
## trait.

@export var chance: float = 0.3
@export var drain_percent_of_max_mp: float = 0.1

func on_before_damage_dealt(ctx: BattleContext, owner: MonsterInstance, target: MonsterInstance, incoming_damage: int, _element: String = "") -> int:
	if not ctx.rng.chance(chance):
		return incoming_damage
	var raw_amount := MathUtils.percent_of(target.species.base_mp, drain_percent_of_max_mp)
	var drained := mini(raw_amount, target.current_mp)
	if drained <= 0:
		return incoming_damage
	target.current_mp -= drained
	owner.current_mp = mini(owner.current_mp + drained, owner.species.base_mp)
	ctx.event_bus.emit_event(
		MpDrainEvent.new(owner.instance_id, target.instance_id, drained),
		ctx.state.turn_number
	)
	return incoming_damage
