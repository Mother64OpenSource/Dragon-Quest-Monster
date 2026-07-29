class_name TeamToBattleBridge
extends RefCounted

## Turns a saved team-builder team into battle-engine MonsterInstances.
## Mirrors game/tests/fixtures/team_builder.gd's construction pattern (slot
## is -1 until BattleSetup/FaintHandler assigns it), but sources
## learned_skills from TeamRosterManager.get_unlocked_skill_ids() -- every
## skill each allocated skillset's own point investment has unlocked, since
## there's no separate "equip a subset of what you've unlocked" step (that
## isn't how these games work -- see MonsterLoadout.skill_point_allocation's
## own doc comment).

## instance_id_offset lets the caller keep ids unique across both teams in
## one battle -- pass 0 for the first team, first_team.size() for the second.
## skillset_db is required (not optional like weapon_db/blacksmith_db below)
## since it's needed just to resolve a monster's own known skills/traits,
## not an optional bonus system. weapon_db/blacksmith_db stay optional
## (default null, backward compatible with every existing call site) --
## when omitted, no equipped_weapon/crafted bonus is resolved onto the
## built instances.
static func build_team(
	saved_team: SavedTeam,
	side: String,
	monster_db: MonsterDatabase,
	skill_db: SkillDatabase,
	trait_db: TraitDatabase,
	skillset_db: SkillSetDatabase,
	instance_id_offset: int,
	weapon_db: WeaponDatabase = null,
	blacksmith_db: BlacksmithDatabase = null
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
		for skill_id in TeamRosterManager.get_unlocked_skill_ids(loadout, species, skillset_db):
			var skill := skill_db.get_skill(skill_id)
			if skill != null:
				skills.append(skill)
			else:
				push_error("Unknown skill id unlocked by %s: %s" % [loadout.species_id, skill_id])
		instance.learned_skills = skills

		var active_trait_ids := TeamRosterManager.get_active_trait_ids(loadout, species, skillset_db)
		var traits: Array[TraitEffect] = []
		for trait_id in active_trait_ids:
			var data := trait_db.get_trait_data(trait_id)
			if data != null:
				var effect := TraitEffect.create(trait_id, data, skill_db)
				if effect != null:
					traits.append(effect)

		if weapon_db != null and not loadout.equipped_weapon_id.is_empty():
			instance.equipped_weapon = weapon_db.get_weapon(loadout.equipped_weapon_id)

		if blacksmith_db != null:
			for item_id in loadout.crafted_blacksmith_ids:
				var item := blacksmith_db.get_item(item_id)
				if item == null:
					push_error("Unknown blacksmith item id crafted by %s: %s" % [loadout.species_id, item_id])
					continue
				match item.category:
					BlacksmithItemData.Category.STAT_BOOST:
						instance.crafted_stat_boosts.append(item)
					BlacksmithItemData.Category.TRAIT_GRANT:
						# "But has no effect on those who already have that
						# bonus" -- skip if this monster already carries this
						# trait (innately, or unlocked via size/synthesis
						# gating), so a granted crit-chance multiplier (etc.)
						# can never stack with its own copy of it.
						if active_trait_ids.has(item.granted_trait_id):
							continue
						var data := trait_db.get_trait_data(item.granted_trait_id)
						if data != null:
							var effect := TraitEffect.create(item.granted_trait_id, data, skill_db)
							if effect != null:
								traits.append(effect)

		instance.active_traits = traits

		team.append(instance)
	return team
