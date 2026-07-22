class_name BattleEngine
extends RefCounted

## Top-level orchestrator. Constructor wires collaborators together; the
## public surface stays intentionally small (start_battle/run_turn/
## run_to_completion) with all real logic delegated to TurnManager and
## friends. Instantiated per-battle — never an autoload — so multiple
## concurrent battles (e.g. a server hosting many matches) share no state.

var battle_state: BattleState
var battle_context: BattleContext
var action_providers: Dictionary
var skill_lookup: Dictionary
var active_slot_count: int

func _init(
	team_a: Array[MonsterInstance],
	team_b: Array[MonsterInstance],
	seed_value: int,
	p_action_providers: Dictionary,
	p_skill_lookup: Dictionary,
	p_active_slot_count: int = 1
) -> void:
	var rng := DeterministicRng.new(seed_value)
	var event_bus := BattleEventBus.new()
	battle_state = BattleState.new(rng, event_bus)
	battle_state.side_a_team = team_a
	battle_state.side_b_team = team_b
	battle_context = BattleContext.new(battle_state)
	action_providers = p_action_providers
	skill_lookup = p_skill_lookup
	active_slot_count = p_active_slot_count

func start_battle() -> void:
	BattleSetup.send_out_initial(battle_context, active_slot_count)

func run_turn() -> void:
	TurnManager.run_turn(battle_context, action_providers, skill_lookup)

## Convenience loop for headless tests/servers: runs turns until the battle
## ends or max_turns is hit (a stalemate/infinite-loop guard, not a rule).
func run_to_completion(max_turns: int) -> Dictionary:
	var turns_run := 0
	while not battle_state.is_battle_over and turns_run < max_turns:
		run_turn()
		turns_run += 1
	return {
		"completed": battle_state.is_battle_over,
		"winner_side": battle_state.winner_side,
		"turns_run": turns_run,
	}

func get_event_bus() -> BattleEventBus:
	return battle_state.event_bus
