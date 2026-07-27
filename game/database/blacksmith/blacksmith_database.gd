class_name BlacksmithDatabase
extends RefCounted

## Real, reusable Blacksmith-item registry, same pattern as WeaponDatabase.

const DEFAULT_FIXTURES_DIR := "res://database/blacksmith/fixtures"

var items_by_id: Dictionary = {}

func _init(source_dir: String = DEFAULT_FIXTURES_DIR) -> void:
	for path in JsonDirLoader.list_json_files(source_dir):
		var item := BlacksmithItemLoader.load_from_file(path)
		if item != null:
			items_by_id[item.id] = item

func get_item(id: String) -> BlacksmithItemData:
	return items_by_id.get(id)

func get_all_items() -> Array[BlacksmithItemData]:
	var result: Array[BlacksmithItemData] = []
	for item in items_by_id.values():
		result.append(item)
	return result
