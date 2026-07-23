class_name MonsterPickerDialog
extends ConfirmationDialog

## Dumb search/select dialog — emits species_chosen(id) and does not construct
## a MonsterLoadout itself; TeamEditorPanel (which owns current_team/roster)
## does that, keeping this dialog reusable.

signal species_chosen(species_id: String)

## Canonical column order from the source spreadsheet's "Base Resistances"
## section (see MonsterSpecies.resistances).
const RESIST_CODES := ["Frz","Siz","Bng","Wsh","Crk","Rbl","Zap","Zam","Dnk","Fre","Ice","Wck","Psn","Crs","Imm","Cnf","Par","Slp","Dzl","DrM","Hck","Fzl","Blt","Abi","Gbs","Ban","Sag","Sap","Dec","Dim"]

var _monster_db: MonsterDatabase

@onready var _search_edit: LineEdit = $VBoxContainer/SearchEdit
@onready var _rank_filter: OptionButton = $VBoxContainer/FiltersRow/RankFilter
@onready var _family_filter: OptionButton = $VBoxContainer/FiltersRow/FamilyFilter
@onready var _results_list: ItemList = $VBoxContainer/ResultsRow/ResultsList
@onready var _details_icon: TextureRect = $VBoxContainer/ResultsRow/DetailsPanel/DetailsIcon
@onready var _details_label: Label = $VBoxContainer/ResultsRow/DetailsPanel/DetailsLabel

func _ready() -> void:
	title = "Add Monster"
	ok_button_text = "Add"
	get_ok_button().disabled = true
	_search_edit.text_changed.connect(_on_filters_changed)
	_rank_filter.item_selected.connect(_on_filters_changed)
	_family_filter.item_selected.connect(_on_filters_changed)
	_results_list.item_selected.connect(_on_result_selected)
	confirmed.connect(_on_confirmed)
	_clear_details()

func setup(monster_db: MonsterDatabase) -> void:
	_monster_db = monster_db
	_populate_rank_filter()
	_populate_family_filter()
	_refresh_results()

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

func _refresh_results() -> void:
	if _monster_db == null:
		return
	var rank_value: Variant = _rank_filter.get_item_metadata(_rank_filter.selected)
	var family_value: String = _family_filter.get_item_metadata(_family_filter.selected)
	var results := _monster_db.find(_search_edit.text, rank_value, family_value)

	_results_list.clear()
	for species in results:
		var idx := _results_list.add_item(
			"%s (%s)" % [species.display_name, MonsterLoader.rank_to_string(species.rank)],
			_load_icon(species)
		)
		_results_list.set_item_metadata(idx, species.id)
	get_ok_button().disabled = true
	_clear_details()

func _on_result_selected(index: int) -> void:
	get_ok_button().disabled = false
	var species_id: String = _results_list.get_item_metadata(index)
	var species := _monster_db.get_species(species_id)
	_show_details(species)

func _on_confirmed() -> void:
	var selected := _results_list.get_selected_items()
	if selected.is_empty():
		return
	var species_id: String = _results_list.get_item_metadata(selected[0])
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
		"%s\nFamily: %s   Rank: %s\n\nHP: %d   MP: %d\nATK: %d   DEF: %d\nAGI: %d   WIS: %d\n\n%s"
		% [
			species.display_name, species.family, MonsterLoader.rank_to_string(species.rank),
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
