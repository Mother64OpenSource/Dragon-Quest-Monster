class_name StatusEffect
extends SkillEffect

## Holds a direct StatusData reference (wired by SkillLoader from the status
## registry at load time) rather than looking an id up at apply-time — this
## is in-process game data composition, not a serialization boundary, so
## there's no need for an id-based runtime lookup.
@export var status_data: StatusData
@export var chance: float = 1.0
@export var target_self: bool = false

func apply(ctx: BattleContext, user: MonsterInstance, target: MonsterInstance) -> void:
	if status_data == null:
		push_error("StatusEffect has no status_data assigned")
		return
	var recipient := user if target_self else target
	if recipient.is_fainted():
		return
	if recipient.active_status != null:
		return
	if not ctx.rng.chance(chance):
		return

	recipient.active_status = StatusInstance.new(status_data)
	ctx.event_bus.emit_event(
		StatusAppliedEvent.new(recipient.instance_id, status_data.id),
		ctx.state.turn_number
	)

	for stat_mod in status_data.stat_mods_on_apply:
		stat_mod.apply(ctx, recipient, recipient)
