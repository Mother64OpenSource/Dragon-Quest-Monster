class_name ActionProvider
extends RefCounted

## The only interface BattleEngine/TurnManager depend on for "what does this
## monster do this turn." UI, network, and AI-difficulty providers all
## implement get_action() and can be swapped in later with zero changes to
## engine code — none of it ever sees a concrete provider type.
func get_action(_state: BattleState, _side: String, _slot: int) -> Action:
	push_error("ActionProvider.get_action() not implemented")
	return null
