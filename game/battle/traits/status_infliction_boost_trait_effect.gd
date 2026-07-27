class_name StatusInflictionBoostTraitEffect
extends TraitEffect

## Generic "crafty_X" status-infliction-boost trait (Crafty Confuser/Curser/
## Paralyzer/Poisoner/Sleeper, plus Crafty Inactivist -> immobilize and
## Crafty Jammer -> dazzle): raises the chance a matching status this
## monster inflicts as the attacker actually lands. Mirrors
## ElementalDamageBoostTraitEffect's placeholder 1.2 damage multiplier for
## consistency -- no sourced real percentage exists here either.
##
## Each real trait's own description also says "no effect on monsters
## immune to X" -- deliberately not modeled: this engine has no per-species
## status-immunity system at all (the `resistances` field on MonsterSpecies
## is purely a cosmetic display value, never read by any battle logic), so
## there is nothing for that clause to hook into. Documented as an honest
## gap rather than silently ignored.
##
## Crafty Jammer is registered as a deliberately partial case: its own
## description spans Dazzle, Drain Magic, and Magic Frailty, but only
## Dazzle maps to a real modeled status -- Drain Magic is a plain elemental
## damage tag with no status attached (see ElementalDamageResistanceTraitEffect's
## own drain_magic_ward registration) and Magic Frailty matches no imported
## skill or mechanic at all.

@export var status_ids: Array[String] = []
@export var infliction_multiplier: float = 1.2

func get_status_infliction_multiplier(status_id: String) -> float:
	return infliction_multiplier if status_ids.has(status_id) else 1.0
