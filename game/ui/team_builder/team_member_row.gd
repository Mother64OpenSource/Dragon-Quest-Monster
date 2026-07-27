class_name TeamMemberRow
extends PanelContainer

## One draggable MonsterLoadout cell. Field edits mutate `loadout` directly
## (it's a plain Resource, no manager call needed) then emit loadout_edited()
## — the parent panel is the one that calls TeamRosterManager.save_team().
## Skill-point allocation across panels lives in SkillPointDialog, opened via
## the "Skills..." button — too much content (multiple panels x up to 10
## thresholds each) to show inline in this compact cell.
##
## Width scales with the species' own slots cost (SPACE_UNIT_WIDTH per
## slot-point) so a 2/3/4-slot monster visibly consumes that many
## slot-points' worth of its party row -- the same "wider card for a
## bigger monster" convention the battle screen's cards and the 3D arena's
## tiles already use, applied here to the team builder's Main/Second Party
## rows (see TeamFormationLayout).

signal loadout_edited()
signal remove_requested()
signal reorder_requested(from_index: int, to_index: int)

const SPACE_UNIT_WIDTH := 120
const CELL_HEIGHT := 150

var loadout: MonsterLoadout
var member_index: int

var _species: MonsterSpecies
var _skill_db: SkillDatabase
var _skillset_db: SkillSetDatabase
var _trait_db: TraitDatabase
var _weapon_db: WeaponDatabase
## Parallel to _weapon_button's item list ("" for the leading "No Weapon"
## entry) -- OptionButton has no built-in way to stash an arbitrary id per
## item, so item index -> weapon id is tracked here instead.
var _weapon_button_ids: Array[String] = []

@onready var _species_icon: TextureRect = $Layout/IconRow/SpeciesIcon
@onready var _nickname_edit: LineEdit = $Layout/NicknameEdit
@onready var _species_label: Label = $Layout/SpeciesLabel
@onready var _traits_label: Label = $Layout/TraitsLabel
@onready var _skills_box: HBoxContainer = $Layout/SkillsBox
@onready var _skills_button: Button = $Layout/SkillsButton
@onready var _weapon_button: OptionButton = $Layout/WeaponButton
@onready var _remove_button: Button = $Layout/IconRow/RemoveButton
@onready var _skill_point_dialog: SkillPointDialog = $SkillPointDialog

func _ready() -> void:
	_nickname_edit.text_submitted.connect(_on_nickname_submitted)
	_nickname_edit.focus_exited.connect(_on_nickname_focus_exited)
	_remove_button.pressed.connect(func() -> void: remove_requested.emit())
	_skills_button.pressed.connect(_on_skills_pressed)
	_skill_point_dialog.allocation_changed.connect(_on_allocation_changed)
	_weapon_button.item_selected.connect(_on_weapon_selected)

func setup(p_loadout: MonsterLoadout, p_index: int, monster_db: MonsterDatabase, skill_db: SkillDatabase, skillset_db: SkillSetDatabase, trait_db: TraitDatabase, weapon_db: WeaponDatabase = null) -> void:
	loadout = p_loadout
	member_index = p_index
	_skill_db = skill_db
	_skillset_db = skillset_db
	_trait_db = trait_db
	_weapon_db = weapon_db
	_species = monster_db.get_species(loadout.species_id)

	_nickname_edit.text = loadout.nickname
	_nickname_edit.placeholder_text = _species.display_name if _species != null else loadout.species_id

	for child in _skills_box.get_children():
		child.queue_free()

	if _species == null:
		custom_minimum_size = Vector2(SPACE_UNIT_WIDTH, CELL_HEIGHT)
		_species_icon.texture = null
		_species_label.text = "Unknown species: '%s'" % loadout.species_id
		_traits_label.visible = false
		_skills_button.visible = false
		_skills_box.visible = true
		_weapon_button.visible = false
		_build_unknown_species_label()
		return

	custom_minimum_size = Vector2(SPACE_UNIT_WIDTH * _species.slots, CELL_HEIGHT)
	_species_icon.texture = load(_species.sprite_path) if not _species.sprite_path.is_empty() else null
	_species_label.text = "%s [Slot %d]" % [_species.display_name, _species.slots]
	_update_traits_label()
	_skills_box.visible = false
	_skills_button.visible = true
	_update_skills_button_text()
	_update_weapon_button()

## Comma-joined names (clipped to one line, matching _species_label's own
## convention) with a composed "Name: description" tooltip per trait joined
## by newlines -- the same composition precedent battle_side_view.gd's
## status badge uses, just covering every trait on the card in one hover
## instead of one icon per status.
func _update_traits_label() -> void:
	if _trait_db == null or _species.starting_trait_ids.is_empty():
		_traits_label.visible = false
		return
	var names: Array[String] = []
	var tooltip_lines: Array[String] = []
	for trait_id in _species.starting_trait_ids:
		var trait_data := _trait_db.get_trait_data(trait_id)
		if trait_data == null:
			continue
		names.append(trait_data.display_name)
		tooltip_lines.append("%s: %s" % [trait_data.display_name, trait_data.description])
	_traits_label.visible = not names.is_empty()
	_traits_label.text = ", ".join(names)
	_traits_label.tooltip_text = "\n".join(tooltip_lines)

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

## Options are filtered to only the weapons this species can actually equip
## (MonsterEquipmentRules.get_equippable_weapon_types(), which also honors
## master_of_weapons) -- rebuilt every setup() call since a species swap
## changes which weapons are even valid options.
func _update_weapon_button() -> void:
	_weapon_button.visible = _weapon_db != null
	if _weapon_db == null:
		return

	_weapon_button.clear()
	_weapon_button_ids.clear()
	_weapon_button.add_item("(No Weapon)")
	_weapon_button_ids.append("")

	var allowed_types := MonsterEquipmentRules.get_equippable_weapon_types(_species)
	var selected_index := 0
	for weapon in _weapon_db.get_all_weapons():
		if not allowed_types.has(WeaponLoader.type_to_string(weapon.weapon_type)):
			continue
		# "(+N ATK)" surfaces the one mechanically-real number (base_attack)
		# right in the option label -- the rest of each weapon's flavor text
		# (elemental bonus, status chance, etc.) is display-only, so it only
		# needs a tooltip, not label space.
		_weapon_button.add_item("%s (+%d ATK)" % [weapon.display_name, weapon.base_attack])
		var item_index := _weapon_button_ids.size()
		_weapon_button_ids.append(weapon.id)
		_weapon_button.set_item_tooltip(item_index, "Base Attack +%d\n%s" % [weapon.base_attack, weapon.description])
		if weapon.id == loadout.equipped_weapon_id:
			selected_index = item_index
	_weapon_button.select(selected_index)

func _on_weapon_selected(index: int) -> void:
	var weapon_id := _weapon_button_ids[index]
	if loadout.equipped_weapon_id == weapon_id:
		return
	loadout.equipped_weapon_id = weapon_id
	loadout_edited.emit()

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
