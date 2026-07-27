class_name EnemyImmobilizeOnEntryTraitEffect
extends TraitEffect

## Generic "immobilizes enemies at the start of a battle" trait (Scare
## Stare, Intimidating, Coercion, Strangely Alluring -- four near-identical
## descriptions, different flavor text, same one class). status_data is
## resolved once at trait-creation time (see TraitEffect.create()'s
## optional skill_db param), same reasoning as RetaliationStatusTraitEffect.
## Rolls independently per enemy, not once for the whole side.

@export var status_data: StatusData
@export var chance: float = 0.3

func on_monster_entered(ctx: BattleContext, owner: MonsterInstance) -> void:
	if status_data == null:
		return
	var enemy_side := "side_b" if owner.side == "side_a" else "side_a"
	for enemy in ctx.state.get_active_monsters(enemy_side):
		if enemy.is_fainted() or enemy.active_status != null:
			continue
		if not ctx.rng.chance(chance):
			continue
		enemy.active_status = StatusInstance.new(status_data)
		ctx.event_bus.emit_event(
			StatusAppliedEvent.new(enemy.instance_id, status_data.id),
			ctx.state.turn_number
		)
