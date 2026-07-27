class_name CounterAttackTraitEffect
extends TraitEffect

## Generic chance-based counterattack. also_negates_damage covers Perfect
## Parry ("avoid all damage AND counter") with the same class as Counter
## Striker (damage still lands, no fusion class needed).

@export var counter_chance: float = 0.25
@export var also_negates_damage: bool = false

func on_before_damage_taken(ctx: BattleContext, owner: MonsterInstance, attacker: MonsterInstance, incoming_damage: int, _element: String = "") -> int:
	if ctx.rng.chance(counter_chance):
		var counter_damage := DamageFormula.calculate(0, owner.get_effective_stat("attack"), attacker.get_effective_stat("defense"))
		var applied := attacker.take_damage(counter_damage)
		ctx.event_bus.emit_event(
			CounterattackEvent.new(owner.instance_id, attacker.instance_id, applied, attacker.current_hp),
			ctx.state.turn_number
		)
		# A counter can be lethal -- EndOfTurnProcessor's own fainted pass
		# skips monsters that are *already* fainted, so without this explicit
		# call the attacker's MonsterFaintedEvent/backfill would never fire.
		FaintHandler.handle_if_fainted(ctx, attacker)
	return 0 if also_negates_damage else incoming_damage
