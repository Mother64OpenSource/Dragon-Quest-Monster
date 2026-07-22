class_name TeamMemberRow
extends PanelContainer

## One draggable MonsterLoadout row. Field edits mutate `loadout` directly
## (it's a plain Resource, no manager call needed) then emit loadout_edited()
## — the parent panel is the one that calls TeamRosterManager.save_team().

signal loadout_edited()
signal remove_requested()
signal reorder_requested(from_index: int, to_index: int)

var loadout: MonsterLoadout
var member_index: int

var _species: MonsterSpecies
var _skill_db: SkillDatabase

@onready var _nickname_edit: LineEdit = $HBoxContainer/NicknameEdit
@onready var _species_label: Label = $HBoxContainer/SpeciesLabel
@onready var _skills_box: HBoxContainer = $HBoxContainer/SkillsBox
@onready var _remove_button: Button = $HBoxContainer/RemoveButton

func _ready() -> void:
	_nickname_edit.text_submitted.connect(_on_nickname_submitted)
	_nickname_edit.focus_exited.connect(_on_nickname_focus_exited)
	_remove_button.pressed.connect(func() -> void: remove_requested.emit())

func setup(p_loadout: MonsterLoadout, p_index: int, monster_db: MonsterDatabase, skill_db: SkillDatabase) -> void:
	loadout = p_loadout
	member_index = p_index
	_skill_db = skill_db
	_species = monster_db.get_species(loadout.species_id)

	_nickname_edit.text = loadout.nickname
	_nickname_edit.placeholder_text = _species.display_name if _species != null else loadout.species_id

	for child in _skills_box.get_children():
		child.queue_free()

	if _species == null:
		_species_label.text = "Unknown species: '%s'" % loadout.species_id
		_build_unknown_species_label()
		return

	_species_label.text = _species.display_name
	_build_skill_checkboxes()

func _build_unknown_species_label() -> void:
	var extra_text := ""
	for i in range(loadout.equipped_skill_ids.size()):
		if i > 0:
			extra_text += ", "
		extra_text += loadout.equipped_skill_ids[i]
	var label := Label.new()
	label.text = "(species unknown — skills not editable): %s" % extra_text
	_skills_box.add_child(label)

func _build_skill_checkboxes() -> void:
	for skill_id in _species.starting_skill_ids:
		_add_skill_checkbox(skill_id, loadout.equipped_skill_ids.has(skill_id), false)
	for skill_id in loadout.equipped_skill_ids:
		if not _species.starting_skill_ids.has(skill_id):
			_add_skill_checkbox(skill_id, true, true)

func _add_skill_checkbox(skill_id: String, checked: bool, is_extra: bool) -> void:
	var checkbox := CheckBox.new()
	var skill := _skill_db.get_skill(skill_id)
	var label_text := skill.display_name if skill != null else skill_id
	if is_extra:
		label_text += " (not known by species)"
	checkbox.text = label_text
	checkbox.button_pressed = checked
	checkbox.toggled.connect(_on_skill_toggled.bind(skill_id))
	_skills_box.add_child(checkbox)

func _on_skill_toggled(is_checked: bool, skill_id: String) -> void:
	if is_checked:
		if not loadout.equipped_skill_ids.has(skill_id):
			loadout.equipped_skill_ids.append(skill_id)
	else:
		loadout.equipped_skill_ids.erase(skill_id)
	loadout_edited.emit()

func _on_nickname_submitted(new_text: String) -> void:
	_apply_nickname(new_text)

func _on_nickname_focus_exited() -> void:
	_apply_nickname(_nickname_edit.text)

func _apply_nickname(new_text: String) -> void:
	if loadout.nickname == new_text:
		return
	loadout.nickname = new_text
	loadout_edited.emit()

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := Label.new()
	preview.text = "Moving: %s" % (_species.display_name if _species != null else loadout.species_id)
	set_drag_preview(preview)
	return {"source": "team_member_row", "from_index": member_index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("source") == "team_member_row"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var from_index: int = data["from_index"]
	reorder_requested.emit(from_index, member_index)
