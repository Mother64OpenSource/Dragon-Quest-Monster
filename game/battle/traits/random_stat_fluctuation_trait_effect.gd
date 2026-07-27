class_name RandomStatFluctuationTraitEffect
extends TraitEffect

## Generic "stat may rise or fall each turn" trait (the Roulette family:
## Agi/Atk/Def/Wis Roulette, Star Gift). One RNG draw per turn start splits
## three ways: [0, rise_chance) rises, [rise_chance, rise_chance+fall_chance)
## falls, otherwise nothing -- deliberately one draw, not two independent
## chance() checks, so the outcome stays reproducible from a fixed seed
## regardless of how the two probabilities happen to be tuned. No sourced
## real values exist for any of these -- documented placeholders, same
## honesty convention as every other invented numeric constant in this
## project (see wiki/log.md).

const STAT_NAMES: Array[String] = ["attack", "defense", "agility", "wisdom"]

@export var stat_name: String = "attack"
@export var rise_chance: float = 0.15
@export var fall_chance: float = 0.15
## Star Gift picks a random stat each time rather than always targeting the
## same one -- true routes through STAT_NAMES instead of the fixed stat_name.
@export var random_stat: bool = false

func on_turn_start(ctx: BattleContext, owner: MonsterInstance) -> void:
	if owner.is_fainted():
		return
	var roll := ctx.rng.randf()
	var delta := 0
	if roll < rise_chance:
		delta = 1
	elif roll < rise_chance + fall_chance:
		delta = -1
	else:
		return

	var target_stat: String = STAT_NAMES[ctx.rng.randi_range(0, STAT_NAMES.size() - 1)] if random_stat else stat_name
	var applied_delta := owner.apply_stat_stage(target_stat, delta)
	var new_stage := owner.stat_stages.get_stage(target_stat)
	ctx.event_bus.emit_event(
		StatChangedEvent.new(owner.instance_id, target_stat, applied_delta, new_stage),
		ctx.state.turn_number
	)
