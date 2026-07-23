class_name MonsterPickerDialog
extends ConfirmationDialog

## Dumb search/select dialog — emits species_chosen(id) and does not construct
## a MonsterLoadout itself; TeamEditorPanel (which owns current_team/roster)
## does that, keeping this dialog reusable. Results render as a sortable
## stat table (icon, name, rank, family, HP/ATK/DEF/AGI/WIS, slots) --
## click a column header to sort by it, click again to reverse.

signal species_chosen(species_id: String)

## Canonical column order from the source spreadsheet's "Base Resistances"
## section (see MonsterSpecies.resistances).
const RESIST_CODES := ["Frz","Siz","Bng","Wsh","Crk","Rbl","Zap","Zam","Dnk","Fre","Ice","Wck","Psn","Crs","Imm","Cnf","Par","Slp","Dzl","DrM","Hck","Fzl","Blt","Abi","Gbs","Ban","Sag","Sap","Dec","Dim"]

const COL_ICON := 0
const COL_NAME := 1
const COL_RANK := 2
const COL_FAMILY := 3
const COL_HP := 4
const COL_ATK := 5
const COL_DEF := 6
const COL_AGI := 7
const COL_WIS := 8
const COL_SLOTS := 9

var _monster_db: MonsterDatabase
var _current_results: Array[MonsterSpecies] = []
var _sort_column: int = COL_NAME
var _sort_ascending: bool = true

@onready var _search_edit: LineEdit = $VBoxContainer/SearchEdit
@onready var _rank_filter: OptionButton = $VBoxContainer/FiltersRow/RankFilter
@onready var _family_filter: OptionButton = $VBoxContainer/FiltersRow/FamilyFilter
@onready var _results_tree: Tree = $VBoxContainer/ResultsRow/ResultsTree
@onready var _details_icon: TextureRect = $VBoxContainer/ResultsRow/DetailsPanel/DetailsIcon
@onready var _details_label: Label = $VBoxContainer/ResultsRow/DetailsPanel/DetailsLabel

func _ready() -> void:
	title = "Add Monster"
	ok_button_text = "Add"
	get_ok_button().disabled = true
	_search_edit.text_changed.connect(_on_filters_changed)
	_rank_filter.item_selected.connect(_on_filters_changed)
	_family_filter.item_selected.connect(_on_filters_changed)
	_setup_tree_columns()
	_results_tree.item_selected.connect(_on_result_selected)
	_results_tree.column_title_clicked.connect(_on_column_title_clicked)
	confirmed.connect(_on_confirmed)
	_clear_details()

func setup(monster_db: MonsterDatabase) -> void:
	_monster_db = monster_db
	_populate_rank_filter()
	_populate_family_filter()
	_refresh_results()

func _setup_tree_columns() -> void:
	_results_tree.columns = 10
	_results_tree.hide_root = true
	_results_tree.column_titles_visible = true
	_results_tree.set_column_title(COL_ICON, "")
	_results_tree.set_column_title(COL_NAME, "Name")
	_results_tree.set_column_title(COL_RANK, "Rank")
	_results_tree.set_column_title(COL_FAMILY, "Family")
	_results_tree.set_column_title(COL_HP, "HP")
	_results_tree.set_column_title(COL_ATK, "ATK")
	_results_tree.set_column_title(COL_DEF, "DEF")
	_results_tree.set_column_title(COL_AGI, "AGI")
	_results_tree.set_column_title(COL_WIS, "WIS")
	_results_tree.set_column_title(COL_SLOTS, "Slots")
	_results_tree.set_column_custom_minimum_width(COL_ICON, 36)
	_results_tree.set_column_custom_minimum_width(COL_NAME, 160)
	_results_tree.set_column_expand(COL_ICON, false)

func _populate_rank_filter() -> void:
	_rank_filter.clear()
	_rank_filter.add_item("Any Rank")
	_rank_filter.set_item_metadata(0, null)
	var ranks := [
		MonsterSpecies.Rank.F, MonsterSpecies.Rank.E, MonsterSpecies.Rank.D,
		MonsterSpecies.Rank.C, MonsterSpecies.Rank.B, MonsterSpecies.Rank.A,
		MonsterSpecies.Rank.S, MonsterSpecies.Rank.SS
	]
	for rank in ranks:
		_rank_filter.add_item(MonsterLoader.rank_to_string(rank))
		_rank_filter.set_item_metadata(_rank_filter.item_count - 1, rank)
	_rank_filter.select(0)

func _populate_family_filter() -> void:
	_family_filter.clear()
	_family_filter.add_item("Any Family")
	_family_filter.set_item_metadata(0, "")
	var families: Array[String] = []
	for species in _monster_db.get_all_species():
		if not families.has(species.family):
			families.append(species.family)
	families.sort()
	for family in families:
		_family_filter.add_item(family)
		_family_filter.set_item_metadata(_family_filter.item_count - 1, family)
	_family_filter.select(0)

func _on_filters_changed(_arg = null) -> void:
	_refresh_results()

func _on_column_title_clicked(column: int, _mouse_button_index: int) -> void:
	if column == COL_ICON:
		return
	if _sort_column == column:
		_sort_ascending = not _sort_ascending
	else:
		_sort_column = column
		_sort_ascending = true
	_populate_tree()

func _refresh_results() -> void:
	if _monster_db == null:
		return
	var rank_value: Variant = _rank_filter.get_item_metadata(_rank_filter.selected)
	var family_value: String = _family_filter.get_item_metadata(_family_filter.selected)
	_current_results = _monster_db.find(_search_edit.text, rank_value, family_value)
	_populate_tree()

func _sort_key(species: MonsterSpecies, column: int) -> Variant:
	match column:
		COL_NAME:
			return species.display_name
		COL_RANK:
			return species.rank
		COL_FAMILY:
			return species.family
		COL_HP:
			return species.base_hp
		COL_ATK:
			return species.base_attack
		COL_DEF:
			return species.base_defense
		COL_AGI:
			return species.base_agility
		COL_WIS:
			return species.base_wisdom
		COL_SLOTS:
			return species.slots
		_:
			return species.display_name

func _populate_tree() -> void:
	var sorted := _current_results.duplicate()
	var column := _sort_column
	var ascending := _sort_ascending
	sorted.sort_custom(func(a, b):
		var ka = _sort_key(a, column)
		var kb = _sort_key(b, column)
		if ka == kb:
			return a.display_name < b.display_name
		return ka < kb if ascending else ka > kb
	)

	_results_tree.clear()
	var root := _results_tree.create_item()
	var row_index := 0
	var alt_bg := Color(0, 0, 0, 0.035)
	for species in sorted:
		var item := _results_tree.create_item(root)
		var icon := _load_icon(species)
		if icon != null:
			item.set_icon(COL_ICON, icon)
			# Tree, unlike ItemList, doesn't auto-constrain icon size to the
			# column width -- without this, sprites render at full native
			# resolution and blow out the whole row.
			item.set_icon_max_width(COL_ICON, 28)
		item.set_text(COL_NAME, species.display_name)
		item.set_text(COL_RANK, MonsterLoader.rank_to_string(species.rank))
		item.set_text(COL_FAMILY, species.family)
		item.set_text(COL_HP, str(species.base_hp))
		item.set_text(COL_ATK, str(species.base_attack))
		item.set_text(COL_DEF, str(species.base_defense))
		item.set_text(COL_AGI, str(species.base_agility))
		item.set_text(COL_WIS, str(species.base_wisdom))
		item.set_text(COL_SLOTS, str(species.slots))
		item.set_metadata(COL_NAME, species.id)

		if row_index % 2 == 1:
			for col in range(_results_tree.columns):
				item.set_custom_bg_color(col, alt_bg)
		row_index += 1

	get_ok_button().disabled = true
	_clear_details()

func _on_result_selected() -> void:
	get_ok_button().disabled = false
	var item := _results_tree.get_selected()
	if item == null:
		return
	var species_id: String = item.get_metadata(COL_NAME)
	var species := _monster_db.get_species(species_id)
	_show_details(species)

func _on_confirmed() -> void:
	var item := _results_tree.get_selected()
	if item == null:
		return
	var species_id: String = item.get_metadata(COL_NAME)
	species_chosen.emit(species_id)

func _load_icon(species: MonsterSpecies) -> Texture2D:
	if species.sprite_path.is_empty():
		return null
	var texture: Texture2D = load(species.sprite_path)
	return texture

func _show_details(species: MonsterSpecies) -> void:
	if species == null:
		_clear_details()
		return
	_details_icon.texture = _load_icon(species)
	_details_label.text = (
		"%s [Slot %d]\nFamily: %s   Rank: %s\n\nHP: %d   MP: %d\nATK: %d   DEF: %d\nAGI: %d   WIS: %d\n\n%s"
		% [
			species.display_name, species.slots, species.family, MonsterLoader.rank_to_string(species.rank),
			species.base_hp, species.base_mp,
			species.base_attack, species.base_defense,
			species.base_agility, species.base_wisdom,
			_format_resistances(species)
		]
	)

## Only non-blank entries are stored on the species, so this always shows
## every code that deviates from normal susceptibility. Symbol meanings
## (½ = resist, ↓ = weak, 0 = immune are the confident ones; ⁎, ↑, ↑↑, ⇄ are
## not yet confirmed) are preserved raw from the source rather than
## interpreted -- see wiki/log.md.
func _format_resistances(species: MonsterSpecies) -> String:
	if species.resistances.is_empty():
		return "Resistances: (none on record)"
	var parts: Array[String] = []
	for code in RESIST_CODES:
		if species.resistances.has(code):
			parts.append("%s %s" % [code, species.resistances[code]])
	return "Resistances:\n" + "   ".join(parts)

func _clear_details() -> void:
	_details_icon.texture = null
	_details_label.text = "Select a monster to see its stats."
