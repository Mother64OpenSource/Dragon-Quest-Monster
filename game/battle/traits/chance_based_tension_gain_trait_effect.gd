class_name ChanceBasedTensionGainTraitEffect
extends TraitEffect

## Generic per-turn tension buildup (Sudden Tension, Random Tension, Rare
## High Tension), rolled once at the start of each of this monster's turns.

@export var chance: float = 0.15
@export var levels: int = 1

func on_turn_start(ctx: BattleContext, owner: MonsterInstance) -> void:
	if ctx.rng.chance(chance):
		owner.tension_level = mini(4, owner.tension_level + levels)
