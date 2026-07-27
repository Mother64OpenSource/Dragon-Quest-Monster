class_name PlayerProfileDialog
extends ConfirmationDialog

## Dumb name+avatar edit dialog -- mirrors MonsterPickerDialog's own "emits,
## doesn't persist" division of responsibility: this dialog only collects
## input and emits profile_saved(), it never touches PlayerProfileManager
## itself. The avatar picker reuses MonsterPickerDialog unmodified (its
## "Add Monster"/"Add" wording is cosmetically off for picking an avatar,
## but functionally harmless -- not worth forking the dialog over).

signal profile_saved(profile: PlayerProfile)

var _monster_db: MonsterDatabase
var _original_profile: PlayerProfile
var _selected_avatar_species_id: String = ""

@onready var _name_edit: LineEdit = $VBoxContainer/NameRow/NameEdit
@onready var _avatar_icon: TextureRect = $VBoxContainer/AvatarRow/AvatarPreviewIcon
@onready var _avatar_label: Label = $VBoxContainer/AvatarRow/AvatarPreviewLabel
@onready var _choose_avatar_button: Button = $VBoxContainer/AvatarRow/ChooseAvatarButton
@onready var _monster_picker: MonsterPickerDialog = $MonsterPickerDialog

func _ready() -> void:
	title = "Edit Profile"
	ok_button_text = "Save"
	_choose_avatar_button.pressed.connect(_on_choose_avatar_pressed)
	_monster_picker.species_chosen.connect(_on_avatar_chosen)
	confirmed.connect(_on_confirmed)

func setup(profile: PlayerProfile, monster_db: MonsterDatabase, trait_db: TraitDatabase) -> void:
	_original_profile = profile
	_monster_db = monster_db
	_monster_picker.setup(monster_db, trait_db)
	_name_edit.text = profile.player_name
	_selected_avatar_species_id = profile.avatar_species_id
	_refresh_avatar_preview()

func _on_choose_avatar_pressed() -> void:
	_monster_picker.popup_centered()

func _on_avatar_chosen(species_id: String) -> void:
	_selected_avatar_species_id = species_id
	_refresh_avatar_preview()

func _refresh_avatar_preview() -> void:
	var species := _monster_db.get_species(_selected_avatar_species_id) if _monster_db != null else null
	if species == null:
		_avatar_icon.texture = null
		_avatar_label.text = "(no avatar)"
		return
	_avatar_icon.texture = load(species.sprite_path) if not species.sprite_path.is_empty() else null
	_avatar_label.text = species.display_name

## A blank name silently reverts to whatever it was before, rather than
## saving an empty display name -- no need for a separate validation
## message for something this minor.
func _on_confirmed() -> void:
	var profile := PlayerProfile.new()
	var trimmed := _name_edit.text.strip_edges()
	profile.player_name = trimmed if not trimmed.is_empty() else _original_profile.player_name
	profile.avatar_species_id = _selected_avatar_species_id
	profile_saved.emit(profile)
