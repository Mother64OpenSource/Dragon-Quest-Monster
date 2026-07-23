class_name SkillSetLoader
extends RefCounted

static func load_from_dict(data: Dictionary) -> SkillSetData:
	var skillset := SkillSetData.new()
	skillset.id = data.get("id", "")
	skillset.display_name = data.get("display_name", skillset.id)

	var thresholds: Array[Dictionary] = []
	for raw in data.get("thresholds", []):
		var t: Dictionary = {"sp": int(raw.get("sp", 0)), "kind": raw.get("kind", "skill")}
		if t["kind"] == "skill":
			t["skill_id"] = raw.get("skill_id", "")
		else:
			t["stat_name"] = raw.get("stat_name", "attack")
			t["amount"] = int(raw.get("amount", 0))
		thresholds.append(t)
	thresholds.sort_custom(func(a, b): return a["sp"] < b["sp"])
	skillset.thresholds = thresholds
	return skillset

static func load_from_file(path: String) -> SkillSetData:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("Failed to parse skillset JSON: %s" % path)
		return null
	return load_from_dict(parsed)
