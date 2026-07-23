class_name SkillSetDatabase
extends RefCounted

const DEFAULT_SKILLSETS_DIR := "res://database/skillsets/fixtures"

var skillsets_by_id: Dictionary = {}

func _init(skillsets_dir: String = DEFAULT_SKILLSETS_DIR) -> void:
	for path in JsonDirLoader.list_json_files(skillsets_dir):
		var skillset := SkillSetLoader.load_from_file(path)
		if skillset != null:
			skillsets_by_id[skillset.id] = skillset

func get_skillset(id: String) -> SkillSetData:
	return skillsets_by_id.get(id)

func get_all_skillsets() -> Array[SkillSetData]:
	var result: Array[SkillSetData] = []
	for skillset in skillsets_by_id.values():
		result.append(skillset)
	return result
