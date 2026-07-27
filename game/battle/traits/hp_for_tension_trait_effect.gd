class_name HpForTensionTraitEffect
extends TraitEffect

## Violent Rager: "Consumes some HP to increase tension in battle." Rolled
## once per owner turn start, same StartOfTurnProcessor timing as the rest
## of the tension-gain family. Costs a percentage of max HP in exchange for
## a tension gain, capped so it never drops the owner below 1 HP -- a
## passive per-turn tax fainting its own owner would be a much bigger
## behavior than "consumes SOME HP" implies, and no other trait in this
## engine risks self-fainting. No sourced real percentage/chance exists --
## documented placeholders, same convention as every other invented
## constant in this project.

@export var hp_cost_percent: float = 0.05
@export var levels: int = 1
@export var chance: float = 1.0

func on_turn_start(ctx: BattleContext, owner: MonsterInstance) -> void:
	if owner.is_fainted() or not ctx.rng.chance(chance):
		return
	var cost := MathUtils.percent_of(owner.species.base_hp, hp_cost_percent)
	var affordable := mini(cost, owner.current_hp - 1)
	if affordable <= 0:
		return
	owner.take_damage(affordable)
	owner.tension_level = mini(4, owner.tension_level + levels)
