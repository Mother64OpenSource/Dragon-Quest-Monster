class_name ActionResolver
extends RefCounted

## Pure sort: priority desc, then effective agility desc, then a seeded RNG
## tiebreak, then submission_index. The tiebreak roll is drawn for every
## action up front, in the fixed canonical order actions were collected in —
## never only "when a tie is detected" — so RNG consumption order never
## depends on runtime tie outcomes, and Array.sort_custom()'s lack of a
## stability guarantee can't affect the result.
static func resolve_order(actions: Array[Action], state: BattleState, skill_lookup: Dictionary) -> Array[Action]:
	var entries: Array[Dictionary] = []
	for action in actions:
		var actor := state.get_monster_by_instance_id(action.actor_instance_id)
		var priority := 0
		var skill: SkillData = skill_lookup.get(action.skill_id)
		if skill != null:
			priority = skill.priority
		if actor != null:
			for trait_effect in actor.active_traits:
				priority += trait_effect.get_priority_bonus()
		var agility := 0
		if actor != null:
			agility = actor.get_effective_stat("agility")
		entries.append({
			"action": action,
			"priority": priority,
			"agility": agility,
			"tiebreak": state.rng.roll_tiebreak(),
		})

	entries.sort_custom(Callable(ActionResolver, "_is_higher_priority"))

	var result: Array[Action] = []
	for entry in entries:
		result.append(entry["action"])
	return result

## Shuffle: "all monsters attack in random order, regardless of AGI or
## traits." A plain Fisher-Yates shuffle using the deterministic RNG,
## bypassing resolve_order's own priority/agility/tiebreak sort entirely
## (not just randomizing among ties) since the trait's own wording says
## AGI/traits don't factor in at all when it's active.
static func shuffle_actions(actions: Array[Action], state: BattleState) -> Array[Action]:
	var result: Array[Action] = actions.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := state.rng.randi_range(0, i)
		var tmp: Action = result[i]
		result[i] = result[j]
		result[j] = tmp
	return result

static func _is_higher_priority(a: Dictionary, b: Dictionary) -> bool:
	if a["priority"] != b["priority"]:
		return a["priority"] > b["priority"]
	if a["agility"] != b["agility"]:
		return a["agility"] > b["agility"]
	if a["tiebreak"] != b["tiebreak"]:
		return a["tiebreak"] > b["tiebreak"]
	var action_a: Action = a["action"]
	var action_b: Action = b["action"]
	return action_a.submission_index < action_b.submission_index
