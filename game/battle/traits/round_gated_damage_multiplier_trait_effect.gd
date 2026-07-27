class_name RoundGatedDamageMultiplierTraitEffect
extends TraitEffect

## Rocket Start: "In the first three rounds, increases damage dealt, but
## thereafter decreases damage dealt." ctx.state.turn_number increments
## once per TurnManager.run_turn() call (confirmed against turn_manager.gd)
## -- a battle-wide round counter, not a per-monster action count, which
## matches "rounds" in the source wording. No sourced real magnitudes exist
## for either the early boost or the late penalty -- documented
## placeholders.

@export var early_round_count: int = 3
@export var early_multiplier: float = 1.3
@export var late_multiplier: float = 0.8

func on_before_damage_dealt(ctx: BattleContext, _owner: MonsterInstance, _target: MonsterInstance, incoming_damage: int, _element: String = "") -> int:
	var multiplier := early_multiplier if ctx.state.turn_number <= early_round_count else late_multiplier
	return MathUtils.round_half_up(float(incoming_damage) * multiplier)
