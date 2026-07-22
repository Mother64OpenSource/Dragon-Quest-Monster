class_name BattleState
extends RefCounted

## Pure data + query helpers — no mutation logic beyond simple bookkeeping.
## side_a_active_slots/side_b_active_slots hold, per active slot, the index
## into the corresponding team array currently occupying it (-1 = empty),
## generalizing 1v1 (one slot) and 2v2 (two slots) uniformly.

var side_a_team: Array[MonsterInstance] = []
var side_b_team: Array[MonsterInstance] = []
var side_a_active_slots: Array[int] = []
var side_b_active_slots: Array[int] = []

var turn_number: int = 0
var rng: DeterministicRng
var event_bus: BattleEventBus
var is_battle_over: bool = false
var winner_side: String = ""

func _init(p_rng: DeterministicRng, p_event_bus: BattleEventBus) -> void:
	rng = p_rng
	event_bus = p_event_bus

func get_active_monsters(side: String) -> Array[MonsterInstance]:
	var team := _team_for_side(side)
	var slots := _active_slots_for_side(side)
	var result: Array[MonsterInstance] = []
	for team_index in slots:
		if team_index >= 0 and team_index < team.size():
			result.append(team[team_index])
	return result

func get_monster_at(side: String, slot: int) -> MonsterInstance:
	var slots := _active_slots_for_side(side)
	if slot < 0 or slot >= slots.size():
		return null
	var team_index := slots[slot]
	var team := _team_for_side(side)
	if team_index < 0 or team_index >= team.size():
		return null
	return team[team_index]

func set_active_at(side: String, slot: int, team_index: int) -> void:
	var slots := _active_slots_for_side(side)
	while slots.size() <= slot:
		slots.append(-1)
	slots[slot] = team_index

func get_active_slot_count(side: String) -> int:
	return _active_slots_for_side(side).size()

func get_monster_by_instance_id(instance_id: int) -> MonsterInstance:
	for monster in side_a_team:
		if monster.instance_id == instance_id:
			return monster
	for monster in side_b_team:
		if monster.instance_id == instance_id:
			return monster
	return null

func all_fainted(side: String) -> bool:
	for monster in _team_for_side(side):
		if not monster.is_fainted():
			return false
	return true

## First team index that is neither fainted nor already occupying an active
## slot on this side, or -1 if none remain — used for automatic backfill
## after a faint (M1 has no strategic switch choice to make, so this is
## deterministic "next in list" rather than a provider-driven decision).
func get_first_reserve_index(side: String) -> int:
	var team := _team_for_side(side)
	var slots := _active_slots_for_side(side)
	for i in range(team.size()):
		if team[i].is_fainted():
			continue
		if slots.has(i):
			continue
		return i
	return -1

func _team_for_side(side: String) -> Array[MonsterInstance]:
	match side:
		"side_a":
			return side_a_team
		"side_b":
			return side_b_team
		_:
			push_error("Unknown side: %s" % side)
			return []

func _active_slots_for_side(side: String) -> Array[int]:
	match side:
		"side_a":
			return side_a_active_slots
		"side_b":
			return side_b_active_slots
		_:
			push_error("Unknown side: %s" % side)
			return []
