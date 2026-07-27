class_name SurviveLethalHitTraitEffect
extends TraitEffect

## Close Scraper/Endure: chance to be left at 1 HP instead of fainting.
## Rolled fresh per hit (see DamageEffect.apply()) -- no per-turn/per-battle
## limit is described in the source data, so a multi-hit skill or a second
## separate attack later the same round can, in principle, proc this again.

@export var chance: float = 0.1

func survives_lethal_hit(ctx: BattleContext, _owner: MonsterInstance) -> bool:
	return ctx.rng.chance(chance)
