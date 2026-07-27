class_name AoeDamageOnFaintTraitEffect
extends TraitEffect

## Last Gasp: deals flat, "unpreventable" damage to every active enemy when
## the owner faints -- applied via take_damage() directly, bypassing
## DamageEffect's whole hook chain (dodge/counter/Defend/crit) entirely,
## since "unpreventable" is the one explicit word in the source
## description. Can itself faint an enemy, chaining into THEIR own
## on_fainted traits -- handled the same way CounterAttackTraitEffect
## already triggers a chained FaintHandler.handle_if_fainted() call.

@export var damage_percent_of_max_hp: float = 0.1

func on_fainted(ctx: BattleContext, owner: MonsterInstance) -> void:
	var enemy_side := "side_b" if owner.side == "side_a" else "side_a"
	for enemy in ctx.state.get_active_monsters(enemy_side):
		if enemy.is_fainted():
			continue
		var amount := maxi(1, MathUtils.percent_of(enemy.species.base_hp, damage_percent_of_max_hp))
		var applied := enemy.take_damage(amount)
		ctx.event_bus.emit_event(
			DamageAppliedEvent.new(owner.instance_id, enemy.instance_id, applied, enemy.current_hp),
			ctx.state.turn_number
		)
		FaintHandler.handle_if_fainted(ctx, enemy)
