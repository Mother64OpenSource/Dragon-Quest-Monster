class_name TeamBuilder
extends RefCounted

## Loads every M1 fixture (status defs, trait defs, skills, monsters) into
## registries, then builds MonsterInstance teams from species ids. Not part
## of the battle engine itself — this is test/fixture-loading plumbing that
## a later real database loader will replace with production data.

const SKILL_FIXTURES_DIR := "res://database/skills/fixtures"
const MONSTER_FIXTURES_DIR := "res://database/monsters/fixtures"
const STATUS_DEFS_DIR := "res://database/status_defs"
const TRAIT_DEFS_DIR := "res://database/traits_defs"

var skill_registry: Dictionary = {}
var monster_registry: Dictionary = {}
var status_registry: Dictionary = {}
var trait_data_registry: Dictionary = {}
var _next_instance_id: int = 1

func _init() -> void:
	_load_all()

func build_team(species_ids: Array[String], side: String) -> Array[MonsterInstance]:
	var team: Array[MonsterInstance] = []
	for i in range(species_ids.size()):
		team.append(_build_monster_instance(species_ids[i], side))
	return team

func _build_monster_instance(species_id: String, side: String) -> MonsterInstance:
	var species: MonsterSpecies = monster_registry.get(species_id)
	if species == null:
		push_error("Unknown species id: %s" % species_id)
		return null

	# slot is -1 (not yet placed) until BattleSetup/FaintHandler assigns it.
	var instance := MonsterInstance.new(_next_instance_id, species, side, -1)
	_next_instance_id += 1

	var skills: Array[SkillData] = []
	for skill_id in species.starting_skill_ids:
		var skill: SkillData = skill_registry.get(skill_id)
		if skill != null:
			skills.append(skill)
		else:
			push_error("Unknown skill id referenced by species %s: %s" % [species_id, skill_id])
	instance.learned_skills = skills

	var traits: Array[TraitEffect] = []
	for trait_id in species.starting_trait_ids:
		var data: TraitData = trait_data_registry.get(trait_id)
		if data != null:
			var effect := TraitEffect.create(trait_id, data)
			if effect != null:
				traits.append(effect)
		else:
			push_error("Unknown trait id referenced by species %s: %s" % [species_id, trait_id])
	instance.active_traits = traits

	return instance

func _load_all() -> void:
	for path in _list_json_files(STATUS_DEFS_DIR):
		var status := StatusData.load_from_file(path)
		if status != null:
			status_registry[status.id] = status

	for path in _list_json_files(TRAIT_DEFS_DIR):
		var data := TraitData.load_from_file(path)
		if data != null:
			trait_data_registry[data.id] = data

	for path in _list_json_files(SKILL_FIXTURES_DIR):
		var skill := SkillLoader.load_from_file(path, status_registry)
		if skill != null:
			skill_registry[skill.id] = skill

	for path in _list_json_files(MONSTER_FIXTURES_DIR):
		var species := MonsterLoader.load_from_file(path)
		if species != null:
			monster_registry[species.id] = species

static func _list_json_files(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("Cannot open directory: %s" % dir_path)
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			result.append(dir_path + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result
