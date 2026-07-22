class_name TraitData
extends Resource

## Flavor/metadata only — behavior lives in TraitEffect.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

static func load_from_dict(data: Dictionary) -> TraitData:
	var result := TraitData.new()
	result.id = data.get("id", "")
	result.display_name = data.get("display_name", result.id)
	result.description = data.get("description", "")
	return result

static func load_from_file(path: String) -> TraitData:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("Failed to parse trait JSON: %s" % path)
		return null
	return load_from_dict(parsed)
