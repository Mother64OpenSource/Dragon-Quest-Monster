class_name SelfSkipTurnTraitEffect
extends TraitEffect

## Generic "occasionally can't act" personality trait (Timid, Yellow Belly,
## Foot Dragger) -- reuses the same skip-turn shape a full-body status
## condition (Sleep/Paralysis/Immobilize/Confusion) already has, but rolled
## from ActionExecutor.execute() independently of any status. No sourced
## real chance exists for any of these -- a documented placeholder.

@export var skip_chance: float = 0.15

func get_self_skip_turn_chance() -> float:
	return skip_chance
