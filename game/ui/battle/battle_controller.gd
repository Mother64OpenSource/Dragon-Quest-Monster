class_name BattleController
extends RefCounted

## Shared per-battle orchestrator, referenced by both BattleSideViews (which
## may live in two different OS windows, but the same process/memory --
## no networking, no serialization). Owns the BattleEngine and the
## per-side action queues; only calls run_turn() once every pending slot on
## both sides has submitted for the round, since ActionProvider.get_action()
## is fully synchronous (no await anywhere in TurnManager's call chain) and
## can't itself wait on a UI click.
##
## Tracking is per SLOT, not per side: with up to 4 monsters active per side,
## each living slot needs its own action this round. A slot's "action" can
## be a skill (submit_fight) or a voluntary swap-in from the bench
## (submit_swap, the "Orders" command) -- a swap consumes that slot's turn
## for the round (the incoming monster gets no queued action, which the
## engine already treats as "does nothing" for a null action) and it acts
## normally starting next round.

const ACTIVE_SLOT_COUNT := 4

signal turn_resolved(events: Array[BattleEvent])
signal battle_ended(winner_side: String)

var engine: BattleEngine
var _providers: Dictionary
var _pending_slots: Dictionary = {"side_a": [], "side_b": []}
var _submitted_slots: Dictionary = {"side_a": {}, "side_b": {}}
var _pending_events: Array[BattleEvent] = []

func _init(team_a: Array[MonsterInstance], team_b: Array[MonsterInstance], skill_lookup: Dictionary, seed_value: int = 0) -> void:
	_providers = {"side_a": ScriptedActionProvider.new(), "side_b": ScriptedActionProvider.new()}
	engine = BattleEngine.new(team_a, team_b, seed_value, _providers, skill_lookup, ACTIVE_SLOT_COUNT)
	engine.get_event_bus().event_emitted.connect(_on_event_emitted)
	engine.start_battle()
	_recompute_pending_slots()

func get_state() -> BattleState:
	return engine.battle_state

func is_over() -> bool:
	return engine.battle_state.is_battle_over

## Slots on this side that need an action this round (had a living monster
## when the round started -- a team smaller than 4 just has fewer of these).
func get_pending_slots(side: String) -> Array:
	return _pending_slots[side].duplicate()

func is_slot_submitted(side: String, slot: int) -> bool:
	return _submitted_slots[side].has(slot)

func is_side_ready(side: String) -> bool:
	for slot in _pending_slots[side]:
		if not _submitted_slots[side].has(slot):
			return false
	return true

## Living team members not currently occupying any active slot -- the
## Orders/swap-in candidates.
func get_living_bench(side: String) -> Array[MonsterInstance]:
	var state := engine.battle_state
	var team: Array[MonsterInstance] = state.side_a_team if side == "side_a" else state.side_b_team
	var active := state.get_active_monsters(side)
	var result: Array[MonsterInstance] = []
	for instance in team:
		if instance.is_fainted():
			continue
		if active.has(instance):
			continue
		result.append(instance)
	return result

func submit_fight(side: String, slot: int, skill_id: String, target_instance_id: int) -> void:
	if is_over() or not _pending_slots[side].has(slot) or _submitted_slots[side].has(slot):
		return
	var actor := engine.battle_state.get_monster_at(side, slot)
	if actor == null:
		return
	var skill: SkillData = engine.skill_lookup.get(skill_id)
	if skill == null:
		push_error("Unknown skill id submitted: %s" % skill_id)
		return

	var target_id := target_instance_id
	if skill.target_type == SkillData.TargetType.SELF:
		target_id = actor.instance_id

	var action := Action.new(actor.instance_id, skill_id, target_id)
	var queue: Array[Action] = [action]
	_providers[side].set_queue(actor.instance_id, queue)
	_submitted_slots[side][slot] = true
	_maybe_resolve_turn()

## The "Orders" command: swap a living bench monster into `slot`, consuming
## that slot's action for the round (it sits out until next round).
func submit_swap(side: String, slot: int, bench_instance_id: int) -> void:
	if is_over() or not _pending_slots[side].has(slot) or _submitted_slots[side].has(slot):
		return
	var state := engine.battle_state
	var team: Array[MonsterInstance] = state.side_a_team if side == "side_a" else state.side_b_team
	var team_index := -1
	for i in range(team.size()):
		if team[i].instance_id == bench_instance_id:
			team_index = i
			break
	if team_index == -1:
		return
	state.set_active_at(side, slot, team_index)
	_submitted_slots[side][slot] = true
	_maybe_resolve_turn()

func _maybe_resolve_turn() -> void:
	if is_side_ready("side_a") and is_side_ready("side_b"):
		_resolve_turn()

func _resolve_turn() -> void:
	_pending_events = []
	engine.run_turn()

	turn_resolved.emit(_pending_events)

	if is_over():
		battle_ended.emit(engine.battle_state.winner_side)
	else:
		_recompute_pending_slots()

func _recompute_pending_slots() -> void:
	var state := engine.battle_state
	for side in ["side_a", "side_b"]:
		var pending: Array = []
		for slot in range(ACTIVE_SLOT_COUNT):
			var monster := state.get_monster_at(side, slot)
			if monster != null and not monster.is_fainted():
				pending.append(slot)
		_pending_slots[side] = pending
		_submitted_slots[side] = {}

func _on_event_emitted(event: BattleEvent) -> void:
	_pending_events.append(event)
