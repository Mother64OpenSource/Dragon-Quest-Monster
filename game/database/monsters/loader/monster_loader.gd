class_name MonsterLoader
extends RefCounted

static func load_from_dict(data: Dictionary) -> MonsterSpecies:
	var species := MonsterSpecies.new()
	species.id = data.get("id", "")
	species.display_name = data.get("display_name", species.id)
	species.family = data.get("family", "")
	species.base_hp = int(data.get("base_hp", 1))
	species.base_mp = int(data.get("base_mp", 0))
	species.base_attack = int(data.get("base_attack", 1))
	species.base_defense = int(data.get("base_defense", 1))
	species.base_agility = int(data.get("base_agility", 1))
	species.base_wisdom = int(data.get("base_wisdom", 1))
	species.rank = _parse_rank(data.get("rank", "F"))
	species.starting_skill_ids = _to_string_array(data.get("starting_skill_ids", []))
	species.starting_trait_ids = _to_string_array(data.get("starting_trait_ids", []))
	species.sprite_path = data.get("sprite_path", "")
	species.resistances = data.get("resistances", {})
	return species

static func load_from_file(path: String) -> MonsterSpecies:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("Failed to parse monster JSON: %s" % path)
		return null
	return load_from_dict(parsed)

static func _parse_rank(value: String) -> MonsterSpecies.Rank:
	match value:
		"F":
			return MonsterSpecies.Rank.F
		"E":
			return MonsterSpecies.Rank.E
		"D":
			return MonsterSpecies.Rank.D
		"C":
			return MonsterSpecies.Rank.C
		"B":
			return MonsterSpecies.Rank.B
		"A":
			return MonsterSpecies.Rank.A
		"S":
			return MonsterSpecies.Rank.S
		"SS":
			return MonsterSpecies.Rank.SS
		_:
			push_error("Unknown monster rank: %s" % value)
			return MonsterSpecies.Rank.F

static func rank_to_string(rank: MonsterSpecies.Rank) -> String:
	match rank:
		MonsterSpecies.Rank.F:
			return "F"
		MonsterSpecies.Rank.E:
			return "E"
		MonsterSpecies.Rank.D:
			return "D"
		MonsterSpecies.Rank.C:
			return "C"
		MonsterSpecies.Rank.B:
			return "B"
		MonsterSpecies.Rank.A:
			return "A"
		MonsterSpecies.Rank.S:
			return "S"
		MonsterSpecies.Rank.SS:
			return "SS"
		_:
			push_error("Unknown monster rank enum value: %d" % rank)
			return "F"

static func _to_string_array(raw: Array) -> Array[String]:
	var result: Array[String] = []
	for item in raw:
		result.append(String(item))
	return result
