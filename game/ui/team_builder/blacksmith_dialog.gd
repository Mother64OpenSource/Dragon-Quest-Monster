class_name BlacksmithDialog
extends AcceptDialog

## Blacksmith bonus picker for one MonsterLoadout: a checkbox per real
## BlacksmithItemData (see wiki/log.md for exactly which 25 of the source
## spreadsheet's 77 items are mechanically wired). No cost/points to
## allocate, unlike SkillPointDialog -- this engine has no inventory or
## currency system, so crafting materials are shown as flavor text only
## (see BlacksmithItemData's own doc comment); toggling a checkbox applies
## or removes the bonus immediately, free and unlimited.

signal items_changed()

var _loadout: MonsterLoadout
var _species: MonsterSpecies
var _blacksmith_db: BlacksmithDatabase

@onready var _header_label: Label = $VBoxContainer/HeaderLabel
@onready var _items_list: VBoxContainer = $VBoxContainer/ScrollContainer/ItemsList

func _ready() -> void:
	get_ok_button().text = "Close"

func show_for(loadout: MonsterLoadout, species: MonsterSpecies, blacksmith_db: BlacksmithDatabase) -> void:
	_loadout = loadout
	_species = species
	_blacksmith_db = blacksmith_db
	title = "Blacksmith — %s" % species.display_name
	_update_header()
	_rebuild()
	popup_centered(Vector2i(420, 480))

func _update_header() -> void:
	_header_label.text = "%s — Crafted Bonuses: %d" % [_species.display_name, _loadout.crafted_blacksmith_ids.size()]

func _rebuild() -> void:
	for child in _items_list.get_children():
		_items_list.remove_child(child)
		child.queue_free()

	var all_items := _blacksmith_db.get_all_items()
	var stat_items: Array[BlacksmithItemData] = []
	var trait_items: Array[BlacksmithItemData] = []
	for item in all_items:
		if item.category == BlacksmithItemData.Category.STAT_BOOST:
			stat_items.append(item)
		else:
			trait_items.append(item)
	stat_items.sort_custom(func(a, b): return a.display_name < b.display_name)
	trait_items.sort_custom(func(a, b): return a.display_name < b.display_name)

	_add_section_label("Stat Boosts")
	for item in stat_items:
		_items_list.add_child(_build_item_checkbox(item))
	_add_section_label("Traits")
	for item in trait_items:
		_items_list.add_child(_build_item_checkbox(item))

func _add_section_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	_items_list.add_child(label)

func _build_item_checkbox(item: BlacksmithItemData) -> CheckBox:
	var checkbox := CheckBox.new()
	checkbox.text = item.display_name
	checkbox.button_pressed = _loadout.crafted_blacksmith_ids.has(item.id)
	checkbox.tooltip_text = "%s\n\nMaterials: %s" % [item.description, item.materials_text]
	checkbox.toggled.connect(_on_item_toggled.bind(item.id))
	return checkbox

func _on_item_toggled(is_checked: bool, item_id: String) -> void:
	if is_checked:
		if not _loadout.crafted_blacksmith_ids.has(item_id):
			_loadout.crafted_blacksmith_ids.append(item_id)
	else:
		_loadout.crafted_blacksmith_ids.erase(item_id)
	_update_header()
	items_changed.emit()
