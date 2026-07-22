class_name StatStages
extends RefCounted

## Typed struct instead of a Dictionary — buff/debuff state must never be
## iterated in a way that could affect simulation order/outcome.

const MIN_STAGE := -6
const MAX_STAGE := 6

var attack: int = 0
var defense: int = 0
var agility: int = 0
var wisdom: int = 0

func get_stage(stat_name: String) -> int:
	match stat_name:
		"attack":
			return attack
		"defense":
			return defense
		"agility":
			return agility
		"wisdom":
			return wisdom
		_:
			push_error("Unknown stat name: %s" % stat_name)
			return 0

## Applies delta, clamped to [MIN_STAGE, MAX_STAGE]. Returns the actual change
## applied after clamping (may be 0 if already at the limit).
func modify(stat_name: String, delta: int) -> int:
	var before := get_stage(stat_name)
	var after := clampi(before + delta, MIN_STAGE, MAX_STAGE)
	match stat_name:
		"attack":
			attack = after
		"defense":
			defense = after
		"agility":
			agility = after
		"wisdom":
			wisdom = after
		_:
			push_error("Unknown stat name: %s" % stat_name)
	return after - before

## Standard Pokémon-style stage curve: stage 0 => 1.0x, +N => (2+N)/2, -N => 2/(2+N).
static func stage_multiplier(stage: int) -> float:
	var clamped := clampi(stage, MIN_STAGE, MAX_STAGE)
	if clamped >= 0:
		return float(2 + clamped) / 2.0
	return 2.0 / float(2 - clamped)
