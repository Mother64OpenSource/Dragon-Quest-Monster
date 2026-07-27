class_name TeamToBattleBridge
extends RefCounted

## Turns a saved team-builder team into battle-engine MonsterInstances.
## Mirrors game/tests/fixtures/team_builder.gd's construction pattern (slot
## is -1 until BattleSetup/FaintHandler assigns it), but sources
## learned_skills from the player's actual equipped_skill_ids on each
## MonsterLoadout rather than a species' full default list.

## instance_id_offset lets the caller keep ids unique across both teams in
## one battle -- pass 0 for the first team, first_team.size() for the second.
## weapon_db is optional (default null, backward compatible with every
## existing call site) -- when omitted, no equipped_weapon is resolved onto
## the built instances, same as if the loadout had no weapon equipped.
static func build_team(
	saved_team: SavedTeam,
	side: String,
	monster_db: MonsterDatabase,
	skill_db: SkillDatabase,
	trait_db: TraitDatabase,
	instance_id_offset: int,
	weapon_db: WeaponDatabase = null
) -> Array[MonsterInstance]:
	var team: Array[MonsterInstance] = []
	for i in range(saved_team.members.size()):
		var loadout := saved_team.members[i]
		var species := monster_db.get_species(loadout.species_id)
		if species == null:
			push_error("Unknown species id in saved team: %s" % loadout.species_id)
			continue

		var instance := MonsterInstance.new(instance_id_offset + i + 1, species, side, -1)

		var skills: Array[SkillData] = []
		for skill_id in loadout.equipped_skill_ids:
			var skill := skill_db.get_skill(skill_id)
			if skill != null:
				skills.append(skill)
			else:
				push_error("Unknown skill id equipped by %s: %s" % [loadout.species_id, skill_id])
		instance.learned_skills = skills

		var traits: Array[TraitEffect] = []
		for trait_id in species.starting_trait_ids:
			var data := trait_db.get_trait_data(trait_id)
			if data != null:
				var effect := TraitEffect.create(trait_id, data, skill_db)
				if effect != null:
					traits.append(effect)
		instance.active_traits = traits

		if weapon_db != null and not loadout.equipped_weapon_id.is_empty():
			instance.equipped_weapon = weapon_db.get_weapon(loadout.equipped_weapon_id)

		team.append(instance)
	return team
