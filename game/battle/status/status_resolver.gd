class_name StatusResolver
extends RefCounted

## Applies one end-of-turn tick for a monster's active status: DOT damage,
## duration decrement, expiry. Called by EndOfTurnProcessor in fixed
## side/slot order, never based on Dictionary/iteration order.
static func tick(ctx: BattleContext, monster: MonsterInstance) -> void:
	if monster.is_fainted():
		return
	var status_instance := monster.active_status
	if status_instance == null:
		return

	var status_data := status_instance.status_data
	var damage := 0
	if status_data.tick_damage_percent > 0.0:
		var raw_damage := MathUtils.percent_of(monster.species.base_hp, status_data.tick_damage_percent)
		damage = monster.take_damage(raw_damage)

	status_instance.remaining_turns -= 1
	var expired := status_instance.remaining_turns <= 0

	ctx.event_bus.emit_event(
		StatusTickEvent.new(monster.instance_id, status_data.id, damage, monster.current_hp, expired),
		ctx.state.turn_number
	)

	if expired:
		monster.active_status = null
