class_name BlacksmithItemLoader
extends RefCounted

static func load_from_dict(data: Dictionary) -> BlacksmithItemData:
	var item := BlacksmithItemData.new()
	item.id = data.get("id", "")
	item.display_name = data.get("display_name", item.id)
	item.description = data.get("description", "")
	item.materials_text = data.get("materials_text", "")
	item.category = _parse_category(data.get("category", "stat_boost"))
	item.stat_name = data.get("stat_name", "")
	item.flat_bonus = int(data.get("flat_bonus", 0))
	item.granted_trait_id = data.get("granted_trait_id", "")
	return item

static func load_from_file(path: String) -> BlacksmithItemData:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("Failed to parse blacksmith item JSON: %s" % path)
		return null
	return load_from_dict(parsed)

static func _parse_category(value: String) -> BlacksmithItemData.Category:
	match value:
		"stat_boost":
			return BlacksmithItemData.Category.STAT_BOOST
		"trait_grant":
			return BlacksmithItemData.Category.TRAIT_GRANT
		_:
			push_error("Unknown blacksmith item category: %s" % value)
			return BlacksmithItemData.Category.STAT_BOOST
