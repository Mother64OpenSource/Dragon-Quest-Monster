class_name SkillDatabase
extends RefCounted

## Real, reusable skill registry. Loads status defs internally only far
## enough to resolve StatusEffect.status_data during skill construction — no
## standalone status registry is exposed, since nothing outside SkillLoader
## needs one.

const DEFAULT_SKILL_FIXTURES_DIR := "res://database/skills/fixtures"
const DEFAULT_STATUS_DEFS_DIR := "res://database/status_defs"

var skills_by_id: Dictionary = {}

func _init(skill_dir: String = DEFAULT_SKILL_FIXTURES_DIR, status_dir: String = DEFAULT_STATUS_DEFS_DIR) -> void:
	var status_registry: Dictionary = {}
	for path in JsonDirLoader.list_json_files(status_dir):
		var status := StatusData.load_from_file(path)
		if status != null:
			status_registry[status.id] = status

	for path in JsonDirLoader.list_json_files(skill_dir):
		var skill := SkillLoader.load_from_file(path, status_registry)
		if skill != null:
			skills_by_id[skill.id] = skill

func get_skill(id: String) -> SkillData:
	return skills_by_id.get(id)

func get_all_skills() -> Array[SkillData]:
	var result: Array[SkillData] = []
	for skill in skills_by_id.values():
		result.append(skill)
	return result
