class_name ReviveTraitEffect
extends TraitEffect

## Comeback Kid: a slim chance of coming back from a faint with partial HP.
## Fires from FaintHandler.handle_if_fainted() right after the faint (and
## MonsterFaintedEvent) are already confirmed -- raising current_hp back
## above 0 here is what tells the caller to skip backfill entirely (see
## on_fainted's own doc comment on TraitEffect).

@export var chance: float = 0.1
@export var revive_hp_percent: float = 0.25

func on_fainted(ctx: BattleContext, owner: MonsterInstance) -> void:
	if not ctx.rng.chance(chance):
		return
	owner.current_hp = maxi(1, MathUtils.percent_of(owner.species.base_hp, revive_hp_percent))
	ctx.event_bus.emit_event(ReviveEvent.new(owner.instance_id, owner.current_hp), ctx.state.turn_number)
