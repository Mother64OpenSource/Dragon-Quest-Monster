class_name TeamBuilder
extends RefCounted

## Test-only plumbing: builds MonsterInstance teams from species ids for the
## headless battle test, delegating all fixture loading to the real
## MonsterDatabase/SkillDatabase/TraitDatabase registries (Milestone 2) so
## loading logic exists exactly once across the project.

var monster_database: MonsterDatabase
var skill_database: SkillDatabase
var trait_database: TraitDatabase

## Kept as a public alias (same Dictionary instance as skill_database.skills_by_id)
## since battle_test_runner.gd reads this field directly.
var skill_registry: Dictionary

var _next_instance_id: int = 1

func _init() -> void:
	monster_database = MonsterDatabase.new()
	skill_database = SkillDatabase.new()
	trait_database = TraitDatabase.new()
	skill_registry = skill_database.skills_by_id

func build_team(species_ids: Array[String], side: String) -> Array[MonsterInstance]:
	var team: Array[MonsterInstance] = []
	for i in range(species_ids.size()):
		team.append(_build_monster_instance(species_ids[i], side))
	return team

func _build_monster_instance(species_id: String, side: String) -> MonsterInstance:
	var species := monster_database.get_species(species_id)
	if species == null:
		push_error("Unknown species id: %s" % species_id)
		return null

	# slot is -1 (not yet placed) until BattleSetup/FaintHandler assigns it.
	var instance := MonsterInstance.new(_next_instance_id, species, side, -1)
	_next_instance_id += 1

	var skills: Array[SkillData] = []
	for skill_id in species.starting_skill_ids:
		var skill := skill_database.get_skill(skill_id)
		if skill != null:
			skills.append(skill)
		else:
			push_error("Unknown skill id referenced by species %s: %s" % [species_id, skill_id])
	instance.learned_skills = skills

	var traits: Array[TraitEffect] = []
	for trait_id in species.starting_trait_ids:
		var data := trait_database.get_trait_data(trait_id)
		if data != null:
			var effect := TraitEffect.create(trait_id, data)
			if effect != null:
				traits.append(effect)
		else:
			push_error("Unknown trait id referenced by species %s: %s" % [species_id, trait_id])
	instance.active_traits = traits

	return instance
