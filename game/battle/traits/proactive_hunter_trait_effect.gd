class_name ProactiveHunterTraitEffect
extends TraitEffect

## Proactive Hunter: "small increase in damage when attacking enemy that
## has already gone." Reads BattleState.acted_this_turn_instance_ids
## (populated by TurnManager.run_turn(), cleared at the top of every round)
## to check whether the target has already had its own action executed
## this round. No sourced real percentage exists -- a documented
## placeholder.

@export var damage_multiplier: float = 1.15

func on_before_damage_dealt(ctx: BattleContext, _owner: MonsterInstance, target: MonsterInstance, incoming_damage: int, _element: String = "") -> int:
	if not ctx.state.acted_this_turn_instance_ids.has(target.instance_id):
		return incoming_damage
	return MathUtils.round_half_up(float(incoming_damage) * damage_multiplier)
