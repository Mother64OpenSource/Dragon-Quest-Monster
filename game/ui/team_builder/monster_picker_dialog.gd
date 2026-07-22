class_name MonsterPickerDialog
extends ConfirmationDialog

## Dumb search/select dialog — emits species_chosen(id) and does not construct
## a MonsterLoadout itself; TeamEditorPanel (which owns current_team/roster)
## does that, keeping this dialog reusable.

signal species_chosen(species_id: String)

var _monster_db: MonsterDatabase

@onready var _search_edit: LineEdit = $VBoxContainer/SearchEdit
@onready var _rank_filter: OptionButton = $VBoxContainer/FiltersRow/RankFilter
@onready var _family_filter: OptionButton = $VBoxContainer/FiltersRow/FamilyFilter
@onready var _results_list: ItemList = $VBoxContainer/ResultsList

func _ready() -> void:
	title = "Add Monster"
	ok_button_text = "Add"
	get_ok_button().disabled = true
	_search_edit.text_changed.connect(_on_filters_changed)
	_rank_filter.item_selected.connect(_on_filters_changed)
	_family_filter.item_selected.connect(_on_filters_changed)
	_results_list.item_selected.connect(_on_result_selected)
	confirmed.connect(_on_confirmed)

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
		MonsterSpecies.Rank.C, MonsterSpecies.Rank.B, MonsterSpecies.Rank.A, MonsterSpecies.Rank.S
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
		var idx := _results_list.add_item("%s (%s)" % [species.display_name, MonsterLoader.rank_to_string(species.rank)])
		_results_list.set_item_metadata(idx, species.id)
	get_ok_button().disabled = true

func _on_result_selected(_index: int) -> void:
	get_ok_button().disabled = false

func _on_confirmed() -> void:
	var selected := _results_list.get_selected_items()
	if selected.is_empty():
		return
	var species_id: String = _results_list.get_item_metadata(selected[0])
	species_chosen.emit(species_id)
