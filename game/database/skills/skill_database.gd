class_name SkillDatabase
extends RefCounted

## Real, reusable skill registry. Also loads status defs — originally only
## to resolve StatusEffect.status_data during skill construction, now also
## exposed directly (get_status/get_all_statuses) since UI needs to look up
## a status's display_name/description/icon_path for narration and icons.

const DEFAULT_SKILL_FIXTURES_DIR := "res://database/skills/fixtures"
const DEFAULT_STATUS_DEFS_DIR := "res://database/status_defs"

var skills_by_id: Dictionary = {}
var statuses_by_id: Dictionary = {}

func _init(skill_dir: String = DEFAULT_SKILL_FIXTURES_DIR, status_dir: String = DEFAULT_STATUS_DEFS_DIR) -> void:
	for path in JsonDirLoader.list_json_files(status_dir):
		var status := StatusData.load_from_file(path)
		if status != null:
			statuses_by_id[status.id] = status

	for path in JsonDirLoader.list_json_files(skill_dir):
		var skill := SkillLoader.load_from_file(path, statuses_by_id)
		if skill != null:
			skills_by_id[skill.id] = skill

func get_skill(id: String) -> SkillData:
	return skills_by_id.get(id)

func get_all_skills() -> Array[SkillData]:
	var result: Array[SkillData] = []
	for skill in skills_by_id.values():
		result.append(skill)
	return result

func get_status(id: String) -> StatusData:
	return statuses_by_id.get(id)

func get_all_statuses() -> Array[StatusData]:
	var result: Array[StatusData] = []
	for status in statuses_by_id.values():
		result.append(status)
	return result
