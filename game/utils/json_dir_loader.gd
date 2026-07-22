class_name JsonDirLoader
extends RefCounted

## Shared "list every *.json file in a directory" helper, used by every
## database registry (MonsterDatabase/SkillDatabase/TraitDatabase) so the
## directory-scan logic exists exactly once.
static func list_json_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("Cannot open directory: %s" % dir_path)
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			result.append(dir_path + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result
