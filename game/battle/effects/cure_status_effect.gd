class_name CureStatusEffect
extends SkillEffect

## Cures a matching active status off the recipient (Defuddle/Squelch/
## Tingle/Sheen/Lift Demerit/Soothing Vortex/Benediction/Wave of Relief).
## Empty status_ids (the default) cures ANY active status -- used for the
## "cures all"/"nullifies all bad status effects" skills.
##
## target_self is effectively always true in every real registration:
## every one of these skills' own description says "all allies," but this
## engine has no ally-targeting for support skills at all (the same
## established simplification StatModEffect's own buff skills already
## collapse to self-only), so "cures all allies" collapses to "cures the
## caster's own status."
##
## Reuses the exact same direct `active_status = null` mutation already
## used in FaintHandler/StatusResolver/DamageEffect's sleep-wake handling,
## narrated via the same StatusTickEvent(expired=true) event
## CureAllyStatusOnTurnTraitEffect already uses for the identical
## trait-side mechanic (Medicinal Knowledge/Sobering Slap).

@export var status_ids: Array[String] = []
@export var target_self: bool = true

func apply(ctx: BattleContext, user: MonsterInstance, target: MonsterInstance) -> void:
	var recipient := user if target_self else target
	if recipient.is_fainted() or recipient.active_status == null:
		return
	var status_id := recipient.active_status.status_data.id
	if not status_ids.is_empty() and not status_ids.has(status_id):
		return
	recipient.active_status = null
	ctx.event_bus.emit_event(
		StatusTickEvent.new(recipient.instance_id, status_id, 0, recipient.current_hp, true),
		ctx.state.turn_number
	)
