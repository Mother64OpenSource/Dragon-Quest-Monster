class_name SkillPointDialog
extends AcceptDialog

## Skillset-slot editor for one MonsterLoadout, Pokemon-Showdown-moveset-style:
## a fixed number of slots (species.slots + 2 -- 3/4/5/6 for a 1/2/3/4-slot
## monster, the real games' own limit on simultaneous skillsets, see
## wiki/log.md), each either empty (a "+ Add Skillset..." button that expands
## into a search-and-pick list) or holding one skillset with a slider
## controlling its point investment (0 to that panel's own max_sp() -- no
## shared cross-panel pool, skill points are effectively unlimited).
##
## There is deliberately no per-move checkbox anywhere in here: a monster
## simply knows every skill AND carries every trait its current slider
## positions have unlocked (TeamRosterManager.get_unlocked_skill_ids()/
## get_active_trait_ids()) -- crossing a threshold in the real games means
## you have that move/trait, permanently, with no picking-and-choosing among
## already-crossed ones. That's also why sometimes NOT maxing a slider out
## is the right call: a late threshold can grant a trait you don't want.
## Mutates the loadout live (no separate save step, consistent with the rest
## of this screen's auto-save-on-edit approach) and emits allocation_changed()
## after every change so the owning row can update its summary + persist.

const MAX_PICKER_RESULTS := 40

signal allocation_changed()

var _loadout: MonsterLoadout
var _species: MonsterSpecies
var _skill_db: SkillDatabase
var _skillset_db: SkillSetDatabase
var _trait_db: TraitDatabase
var _adding_slot: bool = false
var _picker_search_text: String = ""

@onready var _header_label: Label = $VBoxContainer/HeaderLabel
@onready var _slots_list: VBoxContainer = $VBoxContainer/ScrollContainer/SlotsList

func _ready() -> void:
	get_ok_button().text = "Close"

func show_for(loadout: MonsterLoadout, species: MonsterSpecies, skill_db: SkillDatabase, skillset_db: SkillSetDatabase, trait_db: TraitDatabase) -> void:
	_loadout = loadout
	_species = species
	_skill_db = skill_db
	_skillset_db = skillset_db
	_trait_db = trait_db
	title = "Skillsets — %s" % species.display_name
	_adding_slot = false
	_picker_search_text = ""
	_rebuild()
	popup_centered(Vector2i(560, 560))

func _max_slots() -> int:
	return _species.slots + 2

func _rebuild() -> void:
	for child in _slots_list.get_children():
		_slots_list.remove_child(child)
		child.queue_free()

	var skillset_ids: Array = _loadout.skill_point_allocation.keys()
	var max_slots := _max_slots()
	_header_label.text = "%s — %d/%d skillset slots used" % [_species.display_name, skillset_ids.size(), max_slots]

	for skillset_id in skillset_ids:
		_slots_list.add_child(_build_filled_slot(skillset_id))

	if skillset_ids.size() < max_slots:
		_slots_list.add_child(_build_picker_row() if _adding_slot else _build_add_slot_button())

func _build_add_slot_button() -> Control:
	var button := Button.new()
	button.text = "+ Add Skillset..."
	button.pressed.connect(_on_add_slot_pressed)
	return button

func _on_add_slot_pressed() -> void:
	_adding_slot = true
	_picker_search_text = ""
	_rebuild()

func _build_picker_row() -> Control:
	var vbox := VBoxContainer.new()

	var search := LineEdit.new()
	search.placeholder_text = "Search skillsets..."
	search.text = _picker_search_text
	search.text_changed.connect(_on_picker_search_changed)
	vbox.add_child(search)

	var already_used: Array = _loadout.skill_point_allocation.keys()
	var all_skillsets := _skillset_db.get_all_skillsets()
	all_skillsets.sort_custom(func(a, b): return a.display_name < b.display_name)
	var search_lower := _picker_search_text.strip_edges().to_lower()

	var results_box := VBoxContainer.new()
	var shown := 0
	for skillset in all_skillsets:
		if already_used.has(skillset.id):
			continue
		if not search_lower.is_empty() and not skillset.display_name.to_lower().contains(search_lower):
			continue
		var option := Button.new()
		option.text = skillset.display_name
		option.pressed.connect(_on_skillset_picked.bind(skillset.id))
		results_box.add_child(option)
		shown += 1
		if shown >= MAX_PICKER_RESULTS:
			break

	var results_scroll := ScrollContainer.new()
	results_scroll.custom_minimum_size = Vector2(0, 160)
	results_scroll.add_child(results_box)
	vbox.add_child(results_scroll)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_on_add_slot_cancelled)
	vbox.add_child(cancel)

	return vbox

func _on_picker_search_changed(new_text: String) -> void:
	_picker_search_text = new_text
	_rebuild()

func _on_add_slot_cancelled() -> void:
	_adding_slot = false
	_rebuild()

func _on_skillset_picked(skillset_id: String) -> void:
	_loadout.skill_point_allocation[skillset_id] = 0
	_adding_slot = false
	_rebuild()
	allocation_changed.emit()

func _build_filled_slot(skillset_id: String) -> Control:
	var skillset := _skillset_db.get_skillset(skillset_id)
	var vbox := VBoxContainer.new()

	var header := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = skillset.display_name if skillset != null else skillset_id
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var remove_button := Button.new()
	remove_button.text = "x"
	remove_button.tooltip_text = "Remove this skillset (frees the slot)"
	remove_button.pressed.connect(_on_remove_skillset.bind(skillset_id))
	header.add_child(remove_button)
	vbox.add_child(header)

	var max_sp := skillset.max_sp() if skillset != null else 0
	var current_points: int = int(_loadout.skill_point_allocation.get(skillset_id, 0))

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(80, 0)

	var summary_label := Label.new()
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD

	# The slider's own value_changed fires continuously while dragging (once
	# per integer step, given step=1) -- rebuilding this whole dialog on every
	# tick would free the very slider node being dragged out from under the
	# mouse. Only the two labels get touched per tick; a full _rebuild() only
	# happens for the discrete, one-shot actions below (add/remove/pick).
	var slider_row := HBoxContainer.new()
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = max_sp
	slider.step = 1
	slider.value = current_points
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_points_changed.bind(skillset_id, skillset, max_sp, value_label, summary_label))
	slider_row.add_child(slider)
	slider_row.add_child(value_label)
	vbox.add_child(slider_row)

	_update_value_label(value_label, current_points, max_sp)
	_update_unlocked_summary_label(summary_label, skillset, current_points)
	vbox.add_child(summary_label)

	vbox.add_child(HSeparator.new())

	return vbox

func _update_value_label(value_label: Label, points: int, max_sp: int) -> void:
	value_label.text = "%d / %d SP" % [points, max_sp]

## Comma-joined names of every skill AND trait this panel has unlocked at
## the current point value, each with a "Name: description" tooltip
## composed the same way team_member_row.gd's own traits label already
## does -- this list, not a checkbox, is the entire moveset/trait picture
## for this panel: everything at or below the slider's value is simply
## known/carried, nothing here is independently toggleable.
func _update_unlocked_summary_label(label: Label, skillset: SkillSetData, points: int) -> void:
	if skillset == null:
		label.text = "(unknown skillset)"
		return

	var names: Array[String] = []
	var tooltip_lines: Array[String] = []
	for skill_id in skillset.unlocked_skill_ids(points):
		var skill := _skill_db.get_skill(skill_id)
		var skill_name := skill.display_name if skill != null else skill_id
		names.append(skill_name)
		if skill != null and not skill.description.is_empty():
			tooltip_lines.append("%s: %s" % [skill_name, skill.description])
	for trait_id in skillset.unlocked_trait_ids(points):
		var trait_data := _trait_db.get_trait_data(trait_id) if _trait_db != null else null
		var trait_name := trait_data.display_name if trait_data != null else trait_id
		names.append(trait_name + " (trait)")
		if trait_data != null and not trait_data.description.is_empty():
			tooltip_lines.append("%s: %s" % [trait_name, trait_data.description])

	if names.is_empty():
		label.text = "(nothing unlocked yet)"
		label.tooltip_text = ""
	else:
		label.text = ", ".join(names)
		label.tooltip_text = "\n".join(tooltip_lines)

func _on_remove_skillset(skillset_id: String) -> void:
	_loadout.skill_point_allocation.erase(skillset_id)
	_rebuild()
	allocation_changed.emit()

func _on_points_changed(new_value: float, skillset_id: String, skillset: SkillSetData, max_sp: int, value_label: Label, summary_label: Label) -> void:
	var points := int(new_value)
	_loadout.skill_point_allocation[skillset_id] = points
	_update_value_label(value_label, points, max_sp)
	_update_unlocked_summary_label(summary_label, skillset, points)
	allocation_changed.emit()
