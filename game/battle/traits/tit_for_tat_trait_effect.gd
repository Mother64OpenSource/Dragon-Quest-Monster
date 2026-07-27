class_name TitForTatTraitEffect
extends TraitEffect

## Tit for Tat: "When you are afflicted by a status effect, the enemy will
## also be afflicted." Mirrors the SAME status_data back onto whoever
## inflicted it, constructing StatusInstance directly rather than
## recursively calling StatusEffect.apply() -- the same pattern
## RetaliationStatusTraitEffect/EnemyImmobilizeOnEntryTraitEffect already
## use, and it doubles as the guard against infinite mutual-affliction: if
## inflicter == owner (a self-applied status) or the inflicter already has
## an active_status of their own, nothing happens.

func on_status_afflicted(ctx: BattleContext, owner: MonsterInstance, inflicter: MonsterInstance, status_data: StatusData) -> void:
	if inflicter == owner or inflicter.is_fainted() or inflicter.active_status != null:
		return
	inflicter.active_status = StatusInstance.new(status_data)
	ctx.event_bus.emit_event(
		StatusAppliedEvent.new(inflicter.instance_id, status_data.id),
		ctx.state.turn_number
	)
