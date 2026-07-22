class_name MathUtils
extends RefCounted

## Shared rounding policy so every effect/formula rounds the same way instead
## of each call site picking its own float->int rule.
static func round_half_up(value: float) -> int:
	return int(floor(value + 0.5))

static func percent_of(base: int, percent: float) -> int:
	return round_half_up(float(base) * percent)
