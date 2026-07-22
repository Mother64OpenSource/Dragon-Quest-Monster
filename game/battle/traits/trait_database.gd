class_name TraitDatabase
extends RefCounted

## Real, reusable trait-def registry (metadata only — TraitEffect.create()
## remains the code-side behavior lookup, unaffected by this registry).

const DEFAULT_TRAIT_DEFS_DIR := "res://database/traits_defs"

var trait_data_by_id: Dictionary = {}

func _init(source_dir: String = DEFAULT_TRAIT_DEFS_DIR) -> void:
	for path in JsonDirLoader.list_json_files(source_dir):
		var data := TraitData.load_from_file(path)
		if data != null:
			trait_data_by_id[data.id] = data

func get_trait_data(id: String) -> TraitData:
	return trait_data_by_id.get(id)
