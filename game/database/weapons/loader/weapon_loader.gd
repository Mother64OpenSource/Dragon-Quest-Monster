class_name WeaponLoader
extends RefCounted

static func load_from_dict(data: Dictionary) -> WeaponData:
	var weapon := WeaponData.new()
	weapon.id = data.get("id", "")
	weapon.display_name = data.get("display_name", weapon.id)
	weapon.weapon_type = type_from_string(data.get("weapon_type", "sword"))
	weapon.base_attack = int(data.get("base_attack", 0))
	weapon.description = data.get("description", "")
	weapon.bonus_vs_families = _to_string_array(data.get("bonus_vs_families", []))
	weapon.bonus_damage_multiplier = float(data.get("bonus_damage_multiplier", 1.0))
	weapon.bonus_vs_metal_body_flat = int(data.get("bonus_vs_metal_body_flat", 0))
	weapon.crit_chance_multiplier = float(data.get("crit_chance_multiplier", 1.0))
	weapon.crit_chance_category_filter = int(data.get("crit_chance_category_filter", -1))
	weapon.bonus_stats = _to_float_dict(data.get("bonus_stats", {}))
	weapon.lifesteal_percent = float(data.get("lifesteal_percent", 0.0))
	return weapon

static func load_from_file(path: String) -> WeaponData:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("Failed to parse weapon JSON: %s" % path)
		return null
	return load_from_dict(parsed)

static func type_from_string(value: String) -> WeaponData.Type:
	var index := WeaponData.ALL_TYPE_IDS.find(value)
	if index == -1:
		push_error("Unknown weapon type: %s" % value)
		return WeaponData.Type.SWORD
	return index as WeaponData.Type

static func type_to_string(type: WeaponData.Type) -> String:
	return WeaponData.ALL_TYPE_IDS[type]

static func _to_string_array(raw: Array) -> Array[String]:
	var result: Array[String] = []
	for item in raw:
		result.append(String(item))
	return result

static func _to_float_dict(raw: Dictionary) -> Dictionary:
	var result := {}
	for key in raw:
		result[key] = float(raw[key])
	return result
