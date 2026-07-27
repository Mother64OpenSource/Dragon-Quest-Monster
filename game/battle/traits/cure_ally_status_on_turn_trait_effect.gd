class_name CureAllyStatusOnTurnTraitEffect
extends TraitEffect

## Medicinal Knowledge: "Squelches poisoned and envenomed allies in
## battle." This engine only has one poison-family status ("poison" --
## there's no separate "envenomed" tier), so both words in the source
## description map to the same single status_ids entry. Rolled once per
## owner turn start (same StartOfTurnProcessor timing as the tension-gain
## family), checked against every active ally including the owner itself.
## Reuses StatusTickEvent(expired=true) for narration rather than a new
## event type -- "the status just ended" is exactly what that event already
## communicates, whatever the reason (the same precedent DamageEffect's own
## sleep-wake-on-damage already established).

@export var status_ids: Array[String] = ["poison"]
@export var chance: float = 0.3

func on_turn_start(ctx: BattleContext, owner: MonsterInstance) -> void:
	if owner.is_fainted() or not ctx.rng.chance(chance):
		return
	for ally in ctx.state.get_active_monsters(owner.side):
		if ally.is_fainted() or ally.active_status == null:
			continue
		if not status_ids.has(ally.active_status.status_data.id):
			continue
		var status_id := ally.active_status.status_data.id
		ally.active_status = null
		ctx.event_bus.emit_event(
			StatusTickEvent.new(ally.instance_id, status_id, 0, ally.current_hp, true),
			ctx.state.turn_number
		)
