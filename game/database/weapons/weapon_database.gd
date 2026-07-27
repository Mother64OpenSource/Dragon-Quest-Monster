class_name WeaponDatabase
extends RefCounted

## Real, reusable weapon registry, same pattern as MonsterDatabase/SkillDatabase.

const DEFAULT_FIXTURES_DIR := "res://database/weapons/fixtures"

var weapons_by_id: Dictionary = {}

func _init(source_dir: String = DEFAULT_FIXTURES_DIR) -> void:
	for path in JsonDirLoader.list_json_files(source_dir):
		var weapon := WeaponLoader.load_from_file(path)
		if weapon != null:
			weapons_by_id[weapon.id] = weapon

func get_weapon(id: String) -> WeaponData:
	return weapons_by_id.get(id)

func get_all_weapons() -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for weapon in weapons_by_id.values():
		result.append(weapon)
	return result

func filter_by_type(type: WeaponData.Type) -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for weapon in get_all_weapons():
		if weapon.weapon_type == type:
			result.append(weapon)
	return result
