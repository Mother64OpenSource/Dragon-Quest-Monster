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
## Purely additive -- unused by local same-process play. NetworkBattleRelay
## (game/net/network_battle_relay.gd) listens for this to forward a locally-
## submitted action to an online opponent. Fires for every submission
## regardless of origin (local UI click or a relay replaying a remote
## action), which is what lets the relay tell the two apart: it only
## forwards when `side` matches its own local_side, since a submission for
## the *other* side only ever happens because the relay itself just replayed
## one that arrived over the network -- forwarding that back out again would
## echo it forever.
signal action_submitted(side: String, slot: int, kind: String, payload: Dictionary)

var engine: BattleEngine
var _providers: Dictionary
var _pending_slots: Dictionary = {"side_a": [], "side_b": []}
var _submitted_slots: Dictionary = {"side_a": {}, "side_b": {}}
var _pending_events: Array[BattleEvent] = []
var _opening_events: Array[BattleEvent] = []

func _init(team_a: Array[MonsterInstance], team_b: Array[MonsterInstance], skill_lookup: Dictionary, seed_value: int = 0) -> void:
	_providers = {"side_a": ScriptedActionProvider.new(), "side_b": ScriptedActionProvider.new()}
	engine = BattleEngine.new(team_a, team_b, seed_value, _providers, skill_lookup, ACTIVE_SLOT_COUNT)
	engine.get_event_bus().event_emitted.connect(_on_event_emitted)
	engine.start_battle()
	# The initial send-out's MonsterEnteredEvents fire here, before either
	# BattleSideView has connected to turn_resolved (that only happens once
	# setup() runs) -- _resolve_turn() would otherwise silently wipe them the
	# moment round 1 resolves, so a battle's opening lineup never actually
	# appeared in the log. Snapshot them separately for views to narrate once
	# they're set up.
	_opening_events = _pending_events.duplicate()
	_recompute_pending_slots()

func get_state() -> BattleState:
	return engine.battle_state

## The initial send-out's events (see _init()) -- narrate these once, when a
## view first connects, since they happened before any view could see them.
func get_opening_events() -> Array[BattleEvent]:
	return _opening_events.duplicate()

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
	action_submitted.emit(side, slot, "fight", {"skill_id": skill_id, "target_instance_id": target_id})
	_maybe_resolve_turn()

## Swaps a living bench monster into `slot`, consuming that slot's action
## for the round (it sits out until next round). Size-aware: the incoming
## monster claims `species.slots` consecutive raw indices starting at
## `slot`, not just `slot` itself -- a prior version wrote only the single
## index regardless of the incoming monster's own size, so swapping in a
## 2+ slot monster left it silently overlapping whatever else already
## occupied the following indices instead of actually displacing it (see
## wiki/log.md). EVERY distinct monster currently occupying any index the
## incoming monster needs is displaced entirely (its whole footprint
## freed, even the part outside the incoming monster's own range, in case
## that neighbor is itself multi-slot) -- not just whatever's at `slot`
## exactly -- so a bigger incoming monster correctly bumps every occupant
## in its way rather than only ever considering the one slot it landed on.
## The only real rejection case left is the incoming monster simply not
## fitting within ACTIVE_SLOT_COUNT starting at `slot` at all.
##
## A slot also counts as swap-eligible (even when NOT in _pending_slots)
## if its current occupant is fainted: _recompute_pending_slots() deliberately
## excludes a fainted occupant from "needs a command" every round (it can't
## act), but that meant a fainted slot _try_backfill() couldn't fill from
## reserves (no size-compatible fit, see faint_handler.gd) was permanently
## stuck -- never pending again in any future round, so this exact,
## legitimate "please let me manually replace my fainted monster" swap
## could never succeed no matter how it was submitted (drag, click, or
## otherwise). See wiki/log.md for the real report this fixes.
func submit_swap(side: String, slot: int, bench_instance_id: int) -> void:
	if is_over() or _submitted_slots[side].has(slot):
		return
	var state := engine.battle_state
	if not _pending_slots[side].has(slot):
		var occupant := state.get_monster_at(side, slot)
		if occupant == null or not occupant.is_fainted():
			return
	var team: Array[MonsterInstance] = state.side_a_team if side == "side_a" else state.side_b_team
	var team_index := -1
	for i in range(team.size()):
		if team[i].instance_id == bench_instance_id:
			team_index = i
			break
	if team_index == -1:
		return

	var incoming_size := team[team_index].species.slots
	if slot + incoming_size > ACTIVE_SLOT_COUNT:
		return

	var displaced_team_indices := {}
	for s in range(slot, slot + incoming_size):
		var occupant := state.get_monster_at(side, s)
		if occupant != null:
			displaced_team_indices[team.find(occupant)] = true

	for displaced_index in displaced_team_indices:
		for s in state.get_slots_for_team_index(side, displaced_index):
			state.set_active_at(side, s, -1)
		team[displaced_index].slot = -1

	for s in range(slot, slot + incoming_size):
		state.set_active_at(side, s, team_index)
	team[team_index].slot = slot

	_submitted_slots[side][slot] = true
	action_submitted.emit(side, slot, "swap", {"bench_instance_id": bench_instance_id})
	_maybe_resolve_turn()

## Immediately ends the battle, crediting the other side with the win --
## a no-op if the battle is already over. Reuses action_submitted (side,
## slot=-1 since no slot is involved, kind="forfeit") purely so
## NetworkBattleRelay's existing forwarding guard (only forwards when
## `side` matches its own local_side) picks this up for free online, the
## same way it already does for submit_fight/submit_swap -- no separate
## network plumbing needed.
func forfeit(side: String) -> void:
	if is_over():
		return
	var state := engine.battle_state
	state.is_battle_over = true
	state.winner_side = "side_b" if side == "side_a" else "side_a"
	action_submitted.emit(side, -1, "forfeit", {})
	battle_ended.emit(state.winner_side)

## Queues a Defend action for `slot` -- halves incoming damage until this
## monster's own next action (see DamageEffect/ActionExecutor). Always
## succeeds, so there's nothing to narrate beyond the DefendEvent itself.
func submit_defend(side: String, slot: int) -> void:
	if is_over() or not _pending_slots[side].has(slot) or _submitted_slots[side].has(slot):
		return
	var actor := engine.battle_state.get_monster_at(side, slot)
	if actor == null:
		return
	var queue: Array[Action] = [Action.new_defend(actor.instance_id)]
	_providers[side].set_queue(actor.instance_id, queue)
	_submitted_slots[side][slot] = true
	action_submitted.emit(side, slot, "defend", {})
	_maybe_resolve_turn()

func _maybe_resolve_turn() -> void:
	if is_side_ready("side_a") and is_side_ready("side_b"):
		_resolve_turn()

func _resolve_turn() -> void:
	_pending_events = []
	engine.run_turn()

	# Recompute (and reset _submitted_slots) for the *new* round BEFORE
	# emitting turn_resolved: BattleSideView's handler calls
	# _advance_to_next_pending_slot() synchronously off this signal, and it
	# needs to see the fresh round's state, not the just-finished round's
	# now-stale "everything already submitted" bookkeeping -- otherwise
	# every slot looks already-submitted forever and neither side can ever
	# act again (both windows stuck on "Waiting for the other side...").
	if not is_over():
		_recompute_pending_slots()

	turn_resolved.emit(_pending_events)

	if is_over():
		battle_ended.emit(engine.battle_state.winner_side)

func _recompute_pending_slots() -> void:
	var state := engine.battle_state
	for side in ["side_a", "side_b"]:
		var pending: Array = []
		# A multi-slot monster occupies more than one raw slot index -- only
		# its first (lowest) slot is pending, matching TurnManager's action
		# collection, or the player would be asked to command it twice.
		var seen_instance_ids := {}
		for slot in range(ACTIVE_SLOT_COUNT):
			var monster := state.get_monster_at(side, slot)
			if monster == null or monster.is_fainted():
				continue
			if seen_instance_ids.has(monster.instance_id):
				continue
			seen_instance_ids[monster.instance_id] = true
			pending.append(slot)
		_pending_slots[side] = pending
		_submitted_slots[side] = {}

func _on_event_emitted(event: BattleEvent) -> void:
	_pending_events.append(event)
