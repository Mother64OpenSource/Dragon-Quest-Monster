class_name EnemyTensionBuffOnEntryTraitEffect
extends TraitEffect

## Rival Riler: "automatically increases tension for all enemies when
## battle begins" -- the enemy-side mirror of AllyTensionBuffOnEntryTraitEffect
## (Rabble Rouser), same on_monster_entered timing (fires only after both
## sides are fully sent out -- see BattleSetup.send_out_initial) and the
## same "side_b if side_a else side_a" enemy-side pattern
## EnemyImmobilizeOnEntryTraitEffect already uses. Unlike Rabble Rouser's
## own "an ally's tension" (singular), this trait's wording is "all
## enemies," so every active enemy is buffed independently rather than
## picking one at random.

@export var levels: int = 1

func on_monster_entered(ctx: BattleContext, owner: MonsterInstance) -> void:
	var enemy_side := "side_b" if owner.side == "side_a" else "side_a"
	for enemy in ctx.state.get_active_monsters(enemy_side):
		enemy.tension_level = mini(4, enemy.tension_level + levels)
