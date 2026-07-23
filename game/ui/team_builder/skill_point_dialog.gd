class_name SkillPointDialog
extends AcceptDialog

## Skill-point allocation editor for one MonsterLoadout: a SpinBox per
## available skillset (species.available_skill_sets) and a checkbox per
## unlocked move within it. Mutates the loadout live (no separate save step,
## consistent with the rest of this screen's auto-save-on-edit approach) and
## emits allocation_changed() after every change so the owning row can update
## its summary + persist.

signal allocation_changed()

var _loadout: MonsterLoadout
var _species: MonsterSpecies
var _skill_db: SkillDatabase
var _skillset_db: SkillSetDatabase

@onready var _header_label: Label = $VBoxContainer/HeaderLabel
@onready var _panels_list: VBoxContainer = $VBoxContainer/ScrollContainer/PanelsList

func _ready() -> void:
	get_ok_button().text = "Close"

func show_for(loadout: MonsterLoadout, species: MonsterSpecies, skill_db: SkillDatabase, skillset_db: SkillSetDatabase) -> void:
	_loadout = loadout
	_species = species
	_skill_db = skill_db
	_skillset_db = skillset_db
	title = "Skill Points — %s" % species.display_name
	_rebuild()
	popup_centered(Vector2i(520, 480))

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

	var total_used := 0
	for skillset_id in _loadout.skill_point_allocation:
		total_used += int(_loadout.skill_point_allocation[skillset_id])
	_header_label.text = "%s — Skill Points: %d / %d" % [_species.display_name, total_used, _species.total_skill_points]

	for skillset_id in _species.available_skill_sets:
		var skillset := _skillset_db.get_skillset(skillset_id)
		if skillset == null:
			continue
		_panels_list.add_child(_build_panel_section(skillset, total_used))

func _build_panel_section(skillset: SkillSetData, total_used: int) -> Control:
	var section := VBoxContainer.new()

	var header := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = skillset.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var current_points: int = int(_loadout.skill_point_allocation.get(skillset.id, 0))
	var other_used := total_used - current_points
	var remaining_for_this := maxi(0, _species.total_skill_points - other_used)

	var spinbox := SpinBox.new()
	spinbox.min_value = 0
	spinbox.max_value = remaining_for_this
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
