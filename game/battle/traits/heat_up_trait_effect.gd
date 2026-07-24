class_name HeatUpTraitEffect
extends TraitEffect

## "Doubles Tension when takes a critical hit" -- a floor bump keeps this
## from being a no-op at tension_level 0.
func on_critical_hit_taken(_ctx: BattleContext, owner: MonsterInstance, _attacker: MonsterInstance) -> void:
	owner.tension_level = maxi(1, mini(4, owner.tension_level * 2))
