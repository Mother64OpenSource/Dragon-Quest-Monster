class_name TeamRosterManager
extends RefCounted

## CRUD, reorder, import/export, and validation for saved player teams.
## create_team()/duplicate_team()/import_*() persist immediately (so they
## show up in list_teams() right away). add_member()/remove_member()/
## move_member() only mutate the in-memory SavedTeam — call save_team()
## explicitly when ready to persist, matching a typical edit-then-save flow.

const DEFAULT_TEAMS_DIR := "user://teams/"

var teams_dir: String

func _init(p_teams_dir: String = DEFAULT_TEAMS_DIR) -> void:
	teams_dir = p_teams_dir if p_teams_dir.ends_with("/") else p_teams_dir + "/"

func create_team(name: String) -> SavedTeam:
	var team := SavedTeam.new()
	team.team_name = name
	team.id = _generate_unique_id(name)
	save_team(team)
	return team

## Deep-copies every member so mutating the duplicate never affects the
## original — a shallow array/Resource copy would leave both teams pointing
## at the same MonsterLoadout instances.
func duplicate_team(team_id: String) -> SavedTeam:
	var original := get_team(team_id)
	if original == null:
		return null

	var copy := SavedTeam.new()
	copy.team_name = original.team_name + " (Copy)"
	copy.id = _generate_unique_id(copy.team_name)

	var members: Array[MonsterLoadout] = []
	for member in original.members:
		members.append(MonsterLoadoutLoader.duplicate_loadout(member))
	copy.members = members

	save_team(copy)
	return copy

func delete_team(team_id: String) -> bool:
	var path := _path_for(team_id)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK

func get_team(team_id: String) -> SavedTeam:
	return SavedTeamLoader.load_from_file(_path_for(team_id))

func list_teams() -> Array[SavedTeam]:
	var result: Array[SavedTeam] = []
	var dir := DirAccess.open(teams_dir)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var team := SavedTeamLoader.load_from_file(teams_dir + file_name)
			if team != null:
				result.append(team)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

func save_team(team: SavedTeam) -> bool:
	return SavedTeamLoader.save_to_file(team, _path_for(team.id))

func add_member(team: SavedTeam, loadout: MonsterLoadout) -> void:
	team.members.append(loadout)

func remove_member(team: SavedTeam, index: int) -> bool:
	if index < 0 or index >= team.members.size():
		return false
	team.members.remove_at(index)
	return true

func move_member(team: SavedTeam, from_index: int, to_index: int) -> bool:
	var count := team.members.size()
	if from_index < 0 or from_index >= count or to_index < 0 or to_index >= count:
		return false
	var member := team.members[from_index]
	team.members.remove_at(from_index)
	team.members.insert(to_index, member)
	return true

func export_team_to_string(team: SavedTeam) -> String:
	return JSON.stringify(SavedTeamLoader.to_dict(team), "  ")

func export_team_to_file(team: SavedTeam, path: String) -> bool:
	return SavedTeamLoader.save_to_file(team, path)

func import_team_from_string(json_text: String, preserve_id: bool = false) -> SavedTeam:
	var team := SavedTeamLoader.load_from_string(json_text)
	return _finish_import(team, preserve_id)

func import_team_from_file(path: String, preserve_id: bool = false) -> SavedTeam:
	var team := SavedTeamLoader.load_from_file(path)
	return _finish_import(team, preserve_id)

func _finish_import(team: SavedTeam, preserve_id: bool) -> SavedTeam:
	if team == null:
		return null
	if not preserve_id or team.id.is_empty():
		team.id = _generate_unique_id(team.team_name)
	save_team(team)
	return team

## Every skill id currently unlocked for this loadout: the species' always-
## known baseline (starting_skill_ids, e.g. "attack") plus whatever each
## allocated skillset's point investment has unlocked so far. Every monster
## can invest points in every skillset that exists, up to that panel's own
## real max rung -- there's no species-specific restriction on *which*
## skillsets are reachable, and no shared cross-panel point pool either,
## since skill points are effectively unlimited in the real games (skill
## seeds are farmable; see wiki/log.md).
static func get_unlocked_skill_ids(loadout: MonsterLoadout, species: MonsterSpecies, skillset_db: SkillSetDatabase) -> Array[String]:
	var result: Array[String] = species.starting_skill_ids.duplicate()
	for skillset_id in loadout.skill_point_allocation:
		var skillset := skillset_db.get_skillset(skillset_id)
		if skillset == null:
			continue
		var points: int = loadout.skill_point_allocation[skillset_id]
		for skill_id in skillset.unlocked_skill_ids(points):
			if not result.has(skill_id):
				result.append(skill_id)
	return result

## Every trait id actually active for this loadout: the species' always-on
## starting_trait_ids, plus whichever of its size_gated_trait_ids/
## synth_gated_trait_ids tiers current_size/synthesis_stack have reached.
## Each tier check is independent (not elif) since both ladders are ordinal
## -- reaching H (3+ slots) implies P (2+) is also unlocked, and reaching
## +★ (100) implies +50 and +25 are too, so a monster at the top of either
## ladder gets every rung below it as well, not just the top one.
static func get_active_trait_ids(loadout: MonsterLoadout, species: MonsterSpecies) -> Array[String]:
	var result: Array[String] = species.starting_trait_ids.duplicate()
	var size := loadout.current_size if loadout.current_size != 0 else species.slots
	if size >= 2:
		_append_new(result, species.size_gated_trait_ids.get("P", []))
	if size >= 3:
		_append_new(result, species.size_gated_trait_ids.get("H", []))
	if size >= 4:
		_append_new(result, species.size_gated_trait_ids.get("G", []))
	var stack := loadout.synthesis_stack
	if stack >= 25:
		_append_new(result, species.synth_gated_trait_ids.get("25", []))
	if stack >= 50:
		_append_new(result, species.synth_gated_trait_ids.get("50", []))
	if stack >= 100:
		_append_new(result, species.synth_gated_trait_ids.get("star", []))
	return result

static func _append_new(result: Array[String], ids: Array) -> void:
	for id in ids:
		if not result.has(id):
			result.append(String(id))

## Empty result means the loadout is valid. weapon_db/blacksmith_db are both
## optional (default null, backward compatible with every existing call
## site) -- when omitted, the corresponding field goes unchecked, same as
## before each field existed.
func validate_member(loadout: MonsterLoadout, monster_db: MonsterDatabase, skillset_db: SkillSetDatabase, weapon_db: WeaponDatabase = null, blacksmith_db: BlacksmithDatabase = null) -> Array[String]:
	var errors: Array[String] = []
	var species := monster_db.get_species(loadout.species_id)
	if species == null:
		errors.append("Unknown species id: %s" % loadout.species_id)
		return errors

	# No shared cross-panel point pool -- skill points are effectively
	# unlimited (skill seeds are farmable; see wiki/log.md). The only real
	# cap is each panel's own ladder: investing past its top rung is
	# meaningless, so that's what gets flagged, not some species-wide total.
	for skillset_id in loadout.skill_point_allocation:
		var allocated: int = int(loadout.skill_point_allocation[skillset_id])
		var skillset := skillset_db.get_skillset(skillset_id)
		if skillset != null and allocated > skillset.max_sp():
			errors.append("Allocated %d points to '%s' but its ladder only goes up to %d" % [allocated, skillset_id, skillset.max_sp()])

	var unlocked := get_unlocked_skill_ids(loadout, species, skillset_db)
	for skill_id in loadout.equipped_skill_ids:
		if not unlocked.has(skill_id):
			errors.append("Skill '%s' is not known by species '%s'" % [skill_id, loadout.species_id])

	if weapon_db != null and not loadout.equipped_weapon_id.is_empty():
		var weapon := weapon_db.get_weapon(loadout.equipped_weapon_id)
		if weapon == null:
			errors.append("Unknown weapon id: %s" % loadout.equipped_weapon_id)
		elif not MonsterEquipmentRules.can_equip(species, weapon):
			errors.append("'%s' cannot equip %s (%s)" % [loadout.species_id, weapon.display_name, WeaponLoader.type_to_string(weapon.weapon_type)])

	if blacksmith_db != null:
		for item_id in loadout.crafted_blacksmith_ids:
			if blacksmith_db.get_item(item_id) == null:
				errors.append("Unknown blacksmith item id: %s" % item_id)

	if loadout.current_size != 0 and (loadout.current_size < 1 or loadout.current_size > 4):
		errors.append("current_size must be 0 (use natural size) or 1-4, got %d" % loadout.current_size)
	if loadout.synthesis_stack < 0 or loadout.synthesis_stack > 100:
		errors.append("synthesis_stack must be 0-100, got %d" % loadout.synthesis_stack)
	return errors

func _generate_unique_id(name: String) -> String:
	var base_slug := _slugify(name)
	if base_slug.is_empty():
		base_slug = "team"
	var candidate := base_slug
	var suffix := 2
	while FileAccess.file_exists(_path_for(candidate)):
		candidate = "%s_%d" % [base_slug, suffix]
		suffix += 1
	return candidate

func _slugify(name: String) -> String:
	var lowered := name.to_lower().strip_edges()
	var result := ""
	var last_was_underscore := false
	for i in range(lowered.length()):
		var c := lowered[i]
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			result += c
			last_was_underscore = false
		elif not last_was_underscore and not result.is_empty():
			result += "_"
			last_was_underscore = true
	if result.ends_with("_"):
		result = result.substr(0, result.length() - 1)
	return result

func _path_for(team_id: String) -> String:
	return teams_dir + team_id + ".json"
