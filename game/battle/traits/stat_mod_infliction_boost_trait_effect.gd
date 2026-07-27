class_name StatModInflictionBoostTraitEffect
extends TraitEffect

## Generic "crafty_X" stat-debuff-infliction-boost trait (Crafty Debuffer:
## "Sag, Sap, Decelerate, Dim spells more effective"). Only covers the
## Sag/Sap/Decelerate portion -- Dim turned out, on checking its real fixture
## data, to be a plain elemental damage move with no StatModEffect attached
## at all (unlike Sag/Sap/Decelerate), the same kind of partial-coverage
## case Crafty Sealer already established: register what actually fits this
## class, document what doesn't. Mirrors StatModResistanceTraitEffect's own
## placeholder magnitude (1.2) for consistency -- no sourced real percentage
## exists here either.

@export var elements: Array[String] = []
@export var infliction_multiplier: float = 1.2

func get_stat_mod_infliction_multiplier(element: String) -> float:
	return infliction_multiplier if elements.has(element) else 1.0
