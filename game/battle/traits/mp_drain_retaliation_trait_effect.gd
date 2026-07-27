class_name MpDrainRetaliationTraitEffect
extends TraitEffect

## Take Magic: chance to drain MP from whoever attacks the owner directly,
## capped at whatever MP the attacker actually has (never goes negative)
## and at the owner's own max MP (never overheals past it). No sourced real
## percentage exists -- a documented placeholder, same honesty convention
## as every other invented numeric constant in this project.

@export var chance: float = 0.3
@export var drain_percent_of_max_mp: float = 0.1

func on_before_damage_taken(ctx: BattleContext, owner: MonsterInstance, attacker: MonsterInstance, incoming_damage: int, _element: String = "") -> int:
	if not ctx.rng.chance(chance):
		return incoming_damage
	var raw_amount := MathUtils.percent_of(attacker.species.base_mp, drain_percent_of_max_mp)
	var drained := mini(raw_amount, attacker.current_mp)
	if drained <= 0:
		return incoming_damage
	attacker.current_mp -= drained
	owner.current_mp = mini(owner.current_mp + drained, owner.species.base_mp)
	ctx.event_bus.emit_event(
		MpDrainEvent.new(owner.instance_id, attacker.instance_id, drained),
		ctx.state.turn_number
	)
	return incoming_damage
