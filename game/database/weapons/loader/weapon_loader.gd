class_name WeaponLoader
extends RefCounted

static func load_from_dict(data: Dictionary) -> WeaponData:
	var weapon := WeaponData.new()
	weapon.id = data.get("id", "")
	weapon.display_name = data.get("display_name", weapon.id)
	weapon.weapon_type = type_from_string(data.get("weapon_type", "sword"))
	weapon.base_attack = int(data.get("base_attack", 0))
	weapon.description = data.get("description", "")
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
