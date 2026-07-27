class_name HealBoostAndMpDiscountTraitEffect
extends TraitEffect

## Health Professional: "Boosts healing spell effects while decreasing MP
## consumption." The heal boost is unconditional (get_heal_multiplier only
## ever fires from inside HealEffect.apply(), so there's nothing else it
## could be boosting). The MP discount, unlike the elemental -meister
## family's get_mp_cost_multiplier(skill), can't key off SkillData.element
## (Health Professional isn't elemental-gated) -- instead it checks whether
## the skill being cast actually contains a HealEffect among its own
## effects, so the discount doesn't leak onto every other skill this
## monster casts. No sourced real percentages exist for either number --
## documented placeholders, same convention as every other invented
## constant in this project.

@export var heal_multiplier: float = 1.3
@export var mp_cost_multiplier: float = 0.75

func get_heal_multiplier() -> float:
	return heal_multiplier

func get_mp_cost_multiplier(skill: SkillData) -> float:
	for effect in skill.effects:
		if effect is HealEffect:
			return mp_cost_multiplier
	return 1.0
