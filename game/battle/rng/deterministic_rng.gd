class_name DeterministicRng
extends RefCounted

## Single seeded RNG stream for one battle. Never use randomize() or the
## bare randi()/randf() global functions anywhere in battle simulation code —
## always go through an instance of this class so results are reproducible.

var seed_value: int
var _rng: RandomNumberGenerator

func _init(p_seed_value: int) -> void:
	seed_value = p_seed_value
	_rng = RandomNumberGenerator.new()
	_rng.seed = p_seed_value

func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

func randf() -> float:
	return _rng.randf()

## Returns true with the given probability in [0.0, 1.0].
func chance(probability: float) -> bool:
	if probability >= 1.0:
		return true
	if probability <= 0.0:
		return false
	return _rng.randf() < probability

## Draws a value used purely to break exact ties in action ordering.
func roll_tiebreak() -> int:
	return _rng.randi()

## Debug/verification only — never branch gameplay logic on this directly.
func get_state() -> int:
	return _rng.state
