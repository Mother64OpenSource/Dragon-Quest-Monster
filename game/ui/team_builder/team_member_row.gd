class_name TeamMemberRow
extends PanelContainer

## One draggable MonsterLoadout row. Field edits mutate `loadout` directly
## (it's a plain Resource, no manager call needed) then emit loadout_edited()
## — the parent panel is the one that calls TeamRosterManager.save_team().
## Skill-point allocation across panels lives in SkillPointDialog, opened via
## the "Skills..." button — too much content (multiple panels x up to 10
## thresholds each) to show inline in this compact row.

signal loadout_edited()
signal remove_requested()
signal reorder_requested(from_index: int, to_index: int)

var loadout: MonsterLoadout
var member_index: int

var _species: MonsterSpecies
var _skill_db: SkillDatabase
var _skillset_db: SkillSetDatabase

@onready var _species_icon: TextureRect = $HBoxContainer/SpeciesIcon
@onready var _nickname_edit: LineEdit = $HBoxContainer/NicknameEdit
@onready var _species_label: Label = $HBoxContainer/SpeciesLabel
@onready var _skills_box: HBoxContainer = $HBoxContainer/SkillsBox
@onready var _skills_button: Button = $HBoxContainer/SkillsButton
@onready var _remove_button: Button = $HBoxContainer/RemoveButton
@onready var _skill_point_dialog: SkillPointDialog = $SkillPointDialog

func _ready() -> void:
	_nickname_edit.text_submitted.connect(_on_nickname_submitted)
	_nickname_edit.focus_exited.connect(_on_nickname_focus_exited)
	_remove_button.pressed.connect(func() -> void: remove_requested.emit())
	_skills_button.pressed.connect(_on_skills_pressed)
	_skill_point_dialog.allocation_changed.connect(_on_allocation_changed)

func setup(p_loadout: MonsterLoadout, p_index: int, monster_db: MonsterDatabase, skill_db: SkillDatabase, skillset_db: SkillSetDatabase) -> void:
	loadout = p_loadout
	member_index = p_index
	_skill_db = skill_db
	_skillset_db = skillset_db
	_species = monster_db.get_species(loadout.species_id)

	_nickname_edit.text = loadout.nickname
	_nickname_edit.placeholder_text = _species.display_name if _species != null else loadout.species_id

	for child in _skills_box.get_children():
		child.queue_free()

	if _species == null:
		_species_icon.texture = null
		_species_label.text = "Unknown species: '%s'" % loadout.species_id
		_skills_button.visible = false
		_skills_box.visible = true
		_build_unknown_species_label()
		return

	_species_icon.texture = load(_species.sprite_path) if not _species.sprite_path.is_empty() else null
	_species_label.text = "%s [Slot %d]" % [_species.display_name, _species.slots]
	_skills_box.visible = false
	_skills_button.visible = true
	_update_skills_button_text()

func _build_unknown_species_label() -> void:
	var extra_text := ""
	for i in range(loadout.equipped_skill_ids.size()):
		if i > 0:
			extra_text += ", "
		extra_text += loadout.equipped_skill_ids[i]
	var label := Label.new()
	label.text = "(species unknown — skills not editable): %s" % extra_text
	_skills_box.add_child(label)

func _update_skills_button_text() -> void:
	_skills_button.text = "Skills (%d)" % loadout.equipped_skill_ids.size()

func _on_skills_pressed() -> void:
	_skill_point_dialog.show_for(loadout, _species, _skill_db, _skillset_db)

func _on_allocation_changed() -> void:
	_update_skills_button_text()
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
