class_name HpGatedTensionJumpTraitEffect
extends TraitEffect

## Generic per-turn tension jump while HP is at or below a threshold
## (Wrath of the Stars, One-Shot Reversal).

@export var hp_threshold_percent: float = 0.25
@export var target_level: int = 4

func on_turn_start(_ctx: BattleContext, owner: MonsterInstance) -> void:
	if owner.current_hp <= owner.species.base_hp * hp_threshold_percent:
		owner.tension_level = maxi(owner.tension_level, target_level)
