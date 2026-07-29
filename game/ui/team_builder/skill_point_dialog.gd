class_name SkillPointDialog
extends AcceptDialog

## Skill-point allocation editor for one MonsterLoadout: a SpinBox per
## skillset and a checkbox per unlocked move within it. Every monster can
## invest points in every skillset that exists, up to that panel's own real
## max rung -- there's no species-specific restriction on which panels are
## reachable, and no shared cross-panel point pool either, since skill points
## are effectively unlimited in the real games (skill seeds are farmable; see
## wiki/log.md). With 200+ panels to page through, a search field filters the
## list down by panel name. Mutates the loadout live (no separate save step,
## consistent with the rest of this screen's auto-save-on-edit approach) and
## emits allocation_changed() after every change so the owning row can update
## its summary + persist.

signal allocation_changed()

var _loadout: MonsterLoadout
var _species: MonsterSpecies
var _skill_db: SkillDatabase
var _skillset_db: SkillSetDatabase
var _search_text: String = ""

@onready var _header_label: Label = $VBoxContainer/HeaderLabel
@onready var _search_edit: LineEdit = $VBoxContainer/SearchEdit
@onready var _panels_list: VBoxContainer = $VBoxContainer/ScrollContainer/PanelsList

func _ready() -> void:
	get_ok_button().text = "Close"
	_search_edit.text_changed.connect(_on_search_text_changed)

func show_for(loadout: MonsterLoadout, species: MonsterSpecies, skill_db: SkillDatabase, skillset_db: SkillSetDatabase) -> void:
	_loadout = loadout
	_species = species
	_skill_db = skill_db
	_skillset_db = skillset_db
	title = "Skill Points — %s" % species.display_name
	_search_text = ""
	_search_edit.text = ""
	_rebuild()
	popup_centered(Vector2i(520, 480))

func _on_search_text_changed(new_text: String) -> void:
	_search_text = new_text
	_rebuild()

func _rebuild() -> void:
	for child in _panels_list.get_children():
		_panels_list.remove_child(child)
		child.queue_free()

	# Prune any equipped skill that a prior edit unlocked but a subsequent
	# reallocation has since re-locked -- it can no longer be equipped.
	var unlocked := TeamRosterManager.get_unlocked_skill_ids(_loadout, _species, _skillset_db)
	for skill_id in _loadout.equipped_skill_ids.duplicate():
		if not unlocked.has(skill_id):
			_loadout.equipped_skill_ids.erase(skill_id)

	_header_label.text = _species.display_name

	var all_skillsets := _skillset_db.get_all_skillsets()
	all_skillsets.sort_custom(func(a, b): return a.display_name < b.display_name)

	var search_lower := _search_text.strip_edges().to_lower()
	for skillset in all_skillsets:
		if not search_lower.is_empty() and not skillset.display_name.to_lower().contains(search_lower):
			continue
		_panels_list.add_child(_build_panel_section(skillset))

func _build_panel_section(skillset: SkillSetData) -> Control:
	var section := VBoxContainer.new()

	var header := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = skillset.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var current_points: int = int(_loadout.skill_point_allocation.get(skillset.id, 0))

	var spinbox := SpinBox.new()
	spinbox.min_value = 0
	spinbox.max_value = skillset.max_sp()
	spinbox.value = current_points
	spinbox.value_changed.connect(_on_points_changed.bind(skillset.id))
	header.add_child(spinbox)
	section.add_child(header)

	for t in skillset.get_skill_thresholds():
		var sp: int = t["sp"]
		var skill_id: String = t["skill_id"]
		var skill := _skill_db.get_skill(skill_id)
		var skill_label := skill.display_name if skill != null else skill_id
		var mp_text := " (%d MP)" % skill.mp_cost if skill != null else ""

		var checkbox := CheckBox.new()
		var unlocked := sp <= current_points
		checkbox.text = "%d SP — %s%s" % [sp, skill_label, mp_text]
		checkbox.disabled = not unlocked
		checkbox.button_pressed = unlocked and _loadout.equipped_skill_ids.has(skill_id)
		checkbox.toggled.connect(_on_skill_toggled.bind(skill_id))
		if skill != null and not skill.description.is_empty():
			checkbox.tooltip_text = skill.description
		section.add_child(checkbox)

	return section

func _on_points_changed(new_value: float, skillset_id: String) -> void:
	_loadout.skill_point_allocation[skillset_id] = int(new_value)
	_rebuild()
	allocation_changed.emit()

func _on_skill_toggled(is_checked: bool, skill_id: String) -> void:
	if is_checked:
		if not _loadout.equipped_skill_ids.has(skill_id):
			_loadout.equipped_skill_ids.append(skill_id)
	else:
		_loadout.equipped_skill_ids.erase(skill_id)
	allocation_changed.emit()
