class_name RetaliationStatusTraitEffect
extends TraitEffect

## Generic "may inflict a status on whoever attacks me directly" trait
## (Poisonous, Poisonous Poke, Paralysing Punch, Sleep Sock, Confusing
## Touch, Cursed Attack, Whack Attack, Paralyzed Attack). status_data is
## resolved once at trait-creation time (see TraitEffect.create()'s
## optional skill_db param) rather than looked up by id here -- mirrors
## StatusEffect.status_data's own load-time resolution, since a mid-battle
## hook has no database reference to look anything up with.

@export var status_data: StatusData
@export var chance: float = 0.3
## Paralyzed Attack only retaliates while the owner is ALREADY afflicted
## with this status itself -- empty (the default) means unconditional.
@export var requires_own_status_id: String = ""

func on_before_damage_taken(ctx: BattleContext, owner: MonsterInstance, attacker: MonsterInstance, incoming_damage: int, _element: String = "") -> int:
	if status_data == null:
		return incoming_damage
	if not requires_own_status_id.is_empty():
		var owner_has_required := owner.active_status != null and owner.active_status.status_data.id == requires_own_status_id
		if not owner_has_required:
			return incoming_damage
	if attacker.active_status != null or not ctx.rng.chance(chance):
		return incoming_damage
	attacker.active_status = StatusInstance.new(status_data)
	ctx.event_bus.emit_event(
		StatusAppliedEvent.new(attacker.instance_id, status_data.id),
		ctx.state.turn_number
	)
	return incoming_damage
