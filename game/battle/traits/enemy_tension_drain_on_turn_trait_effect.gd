class_name EnemyTensionDrainOnTurnTraitEffect
extends TraitEffect

## Mutter: "can lower all enemies' Tension in the middle of a battle" --
## rolled once per owner turn start (same StartOfTurnProcessor already
## driving the tension-gain trait family), applied to every active enemy
## independently. No sourced real chance/magnitude exists -- documented
## placeholders.
##
## require_any_enemy_tension (Heckling Hector: "automatically decreases
## all enemy tension when one enemy increases tension during battle") is a
## documented approximation of a trigger this engine genuinely can't
## observe -- there's no "on any enemy's tension changed" event hook (every
## other trait hook here keys off the OWNER's own state/actions, not a
## side-wide observation). Substitutes a continuous check instead: each of
## the owner's own turns, if ANY active enemy currently has positive
## tension, drain everyone's tension unconditionally (no chance roll, per
## "automatically") rather than reacting to the exact moment it rose.
## Mutually exclusive with chance -- when true, the chance roll is skipped
## entirely.

@export var chance: float = 0.2
@export var levels: int = 1
@export var require_any_enemy_tension: bool = false

func on_turn_start(ctx: BattleContext, owner: MonsterInstance) -> void:
	if owner.is_fainted():
		return
	var enemy_side := "side_b" if owner.side == "side_a" else "side_a"
	var enemies := ctx.state.get_active_monsters(enemy_side)
	if require_any_enemy_tension:
		var any_has_tension := false
		for enemy in enemies:
			if enemy.tension_level > 0:
				any_has_tension = true
				break
		if not any_has_tension:
			return
	elif not ctx.rng.chance(chance):
		return
	for enemy in enemies:
		enemy.tension_level = maxi(0, enemy.tension_level - levels)
