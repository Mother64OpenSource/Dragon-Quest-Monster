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
	species.starting_skill_ids = _to_string_array(data.get("starting_skill_ids", []))
	species.starting_trait_ids = _to_string_array(data.get("starting_trait_ids", []))
	return species

static func load_from_file(path: String) -> MonsterSpecies:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("Failed to parse monster JSON: %s" % path)
		return null
	return load_from_dict(parsed)

static func _to_string_array(raw: Array) -> Array[String]:
	var result: Array[String] = []
	for item in raw:
		result.append(String(item))
	return result
