class_name TensionStealOnAttackedTraitEffect
extends TraitEffect

## Stress Relief: "may occasionally deprive an enemy of its stored Tension
## and take it for itself" -- rolled when the owner is directly attacked,
## same on_before_damage_taken shape MpDrainRetaliationTraitEffect already
## uses for an MP-flavored version of the same idea. Steals the attacker's
## ENTIRE current tension_level (there's no "percent of tension" concept --
## tension is a small 0-4 integer counter, not a pool with a magnitude to
## take a fraction of), capped so the owner never exceeds the max level of
## 4. No sourced real chance exists -- a documented placeholder.

@export var chance: float = 0.3

func on_before_damage_taken(ctx: BattleContext, owner: MonsterInstance, attacker: MonsterInstance, incoming_damage: int, _element: String = "") -> int:
	if attacker.tension_level <= 0 or not ctx.rng.chance(chance):
		return incoming_damage
	var stolen := attacker.tension_level
	attacker.tension_level = 0
	owner.tension_level = mini(4, owner.tension_level + stolen)
	return incoming_damage
