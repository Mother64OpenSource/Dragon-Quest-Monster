class_name DamageFormula
extends RefCounted

## Single source of truth for damage calculation. No randomness lives here —
## accuracy/crit rolls happen at the call site via DeterministicRng so this
## stays a pure, hand-computable function for test assertions.
static func calculate(power: int, offense_stat: int, defense_stat: int) -> int:
	var raw: float = float(offense_stat) + float(power) - float(defense_stat) / 2.0
	return maxi(1, MathUtils.round_half_up(raw))
