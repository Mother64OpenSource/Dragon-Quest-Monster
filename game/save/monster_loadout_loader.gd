class_name MonsterLoadoutLoader
extends RefCounted

static func load_from_dict(data: Dictionary) -> MonsterLoadout:
	var loadout := MonsterLoadout.new()
	loadout.species_id = data.get("species_id", "")
	loadout.nickname = data.get("nickname", "")
	loadout.skill_point_allocation = _to_int_dict(data.get("skill_point_allocation", {}))
	loadout.equipped_weapon_id = data.get("equipped_weapon_id", "")
	loadout.crafted_blacksmith_ids = _to_string_array(data.get("crafted_blacksmith_ids", []))
	loadout.current_size = int(data.get("current_size", 0))
	loadout.synthesis_stack = int(data.get("synthesis_stack", 0))
	return loadout

static func to_dict(loadout: MonsterLoadout) -> Dictionary:
	return {
		"species_id": loadout.species_id,
		"nickname": loadout.nickname,
		"skill_point_allocation": loadout.skill_point_allocation.duplicate(),
		"equipped_weapon_id": loadout.equipped_weapon_id,
		"crafted_blacksmith_ids": loadout.crafted_blacksmith_ids.duplicate(),
		"current_size": loadout.current_size,
		"synthesis_stack": loadout.synthesis_stack,
	}

## Constructs a fresh, independent MonsterLoadout with the same field values —
## used by TeamRosterManager.duplicate_team() so mutating a duplicated team's
## members can never affect the original's.
static func duplicate_loadout(loadout: MonsterLoadout) -> MonsterLoadout:
	var copy := MonsterLoadout.new()
	copy.species_id = loadout.species_id
	copy.nickname = loadout.nickname
	copy.skill_point_allocation = loadout.skill_point_allocation.duplicate()
	copy.equipped_weapon_id = loadout.equipped_weapon_id
	copy.crafted_blacksmith_ids = loadout.crafted_blacksmith_ids.duplicate()
	copy.current_size = loadout.current_size
	copy.synthesis_stack = loadout.synthesis_stack
	return copy

static func _to_string_array(raw: Array) -> Array[String]:
	var result: Array[String] = []
	for item in raw:
		result.append(String(item))
	return result

static func _to_int_dict(raw: Dictionary) -> Dictionary:
	var result := {}
	for key in raw:
		result[key] = int(raw[key])
	return result
