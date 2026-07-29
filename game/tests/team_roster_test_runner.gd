class_name TeamRosterTestRunner
extends RefCounted

## Runs the Milestone 2 (Team Builder data layer) checks end-to-end: database
## search/filter, saved-team CRUD, reorder, import/export round-trip,
## validation, and malformed-input handling. Uses user://test_teams/ (never
## the real user://teams/) and wipes it before and after run() so repeated
## runs stay deterministic and never touch real player save data.

const TEST_TEAMS_DIR := "user://test_teams/"

var _all_passed := true

func run() -> bool:
	_all_passed = true
	_clear_test_dir()

	var monster_db := MonsterDatabase.new()
	var skill_db := SkillDatabase.new()
	var skillset_db := SkillSetDatabase.new()
	var weapon_db := WeaponDatabase.new()
	var roster := TeamRosterManager.new(TEST_TEAMS_DIR)

	_check_database(monster_db, skill_db)
	_check_crud(roster)
	_check_reorder_and_members(roster)
	_check_import_export(roster)
	_check_validation(roster, monster_db, skillset_db)
	_check_weapon_validation(roster, monster_db, skillset_db, weapon_db)
	_check_malformed_import(roster)

	_clear_test_dir()

	if _all_passed:
		print("TeamRosterTestRunner: ALL CHECKS PASSED")
	else:
		print("TeamRosterTestRunner: SOME CHECKS FAILED")
	return _all_passed

func _check_database(monster_db: MonsterDatabase, skill_db: SkillDatabase) -> void:
	# The fixtures directory holds the 4 hand-tuned M1 test species plus a
	# larger real-data batch, so this only floors the count rather than
	# asserting an exact total that would need updating every time fixtures
	# are added.
	_check("at least 4 species loaded", monster_db.get_all_species().size() >= 4)

	var slime := monster_db.get_species("slime")
	_check("slime rank == F", slime != null and slime.rank == MonsterSpecies.Rank.F)
	var dracky := monster_db.get_species("dracky")
	_check("dracky rank == E", dracky != null and dracky.rank == MonsterSpecies.Rank.E)
	var healslime := monster_db.get_species("healslime")
	_check("healslime rank == D", healslime != null and healslime.rank == MonsterSpecies.Rank.D)
	var golem := monster_db.get_species("golem")
	_check("golem rank == C", golem != null and golem.rank == MonsterSpecies.Rank.C)

	var name_results := monster_db.search_by_name("drac")
	var name_result_ids: Array[String] = []
	for species in name_results:
		name_result_ids.append(species.id)
	# Real fixture data adds more "drac"-containing names, so check
	# membership rather than an exact single match.
	_check("search_by_name('drac') includes dracky", name_result_ids.has("dracky"))

	var rank_results := monster_db.filter_by_rank(MonsterSpecies.Rank.C)
	var rank_result_ids: Array[String] = []
	for species in rank_results:
		rank_result_ids.append(species.id)
	# Real fixture data adds many more rank-C monsters, so check membership
	# rather than an exact single match.
	_check("filter_by_rank(C) includes golem", rank_result_ids.has("golem"))

	var family_results := monster_db.filter_by_family("slime")
	var family_ids: Array[String] = []
	for species in family_results:
		family_ids.append(species.id)
	# Real fixture data adds more Slime-family monsters, so check membership
	# rather than an exact list.
	_check(
		"filter_by_family('slime') includes healslime+slime",
		family_ids.has("healslime") and family_ids.has("slime")
	)

	var combined := monster_db.find("", MonsterSpecies.Rank.F, "slime")
	var combined_ids: Array[String] = []
	for species in combined:
		combined_ids.append(species.id)
	# Real fixture data adds more rank-F Slime-family monsters, so check
	# membership rather than an exact single match.
	_check("find(rank=F,family=slime) includes slime", combined_ids.has("slime"))

	# Real fixture data adds many more skills from imported movesets, so check
	# a floor rather than the exact Milestone 1 count.
	_check("SkillDatabase loads at least 7 skills", skill_db.get_all_skills().size() >= 7)
	var frizz := skill_db.get_skill("frizz")
	_check("get_skill('frizz') resolves", frizz != null and frizz.id == "frizz")

func _check_crud(roster: TeamRosterManager) -> void:
	var team := roster.create_team("My Slime Squad")
	_check("create_team returns non-null with generated id", team != null and not team.id.is_empty())
	_check("created team appears in list_teams()", _contains_team_id(roster.list_teams(), team.id))

	var fetched := roster.get_team(team.id)
	_check("get_team round-trips team_name", fetched != null and fetched.team_name == "My Slime Squad")

	var loadout := MonsterLoadout.new()
	loadout.species_id = "slime"
	loadout.nickname = "Sluggo"
	loadout.equipped_skill_ids = ["attack", "oomph"]
	roster.add_member(team, loadout)
	roster.save_team(team)

	var duplicate := roster.duplicate_team(team.id)
	_check("duplicate_team produces a distinct id", duplicate != null and duplicate.id != team.id)
	_check("duplicate has 1 member copied", duplicate.members.size() == 1)

	duplicate.members[0].nickname = "Changed"
	_check("mutating duplicate's loadout doesn't affect in-memory original", team.members[0].nickname == "Sluggo")
	var original_reloaded := roster.get_team(team.id)
	_check("mutating duplicate's loadout doesn't affect original on disk", original_reloaded.members[0].nickname == "Sluggo")

	_check("delete_team returns true", roster.delete_team(duplicate.id))
	_check("deleted team no longer in list_teams()", not _contains_team_id(roster.list_teams(), duplicate.id))

	roster.delete_team(team.id)

func _check_reorder_and_members(roster: TeamRosterManager) -> void:
	var team := roster.create_team("Reorder Test")
	var a := MonsterLoadout.new()
	a.species_id = "slime"
	var b := MonsterLoadout.new()
	b.species_id = "dracky"
	var c := MonsterLoadout.new()
	c.species_id = "golem"
	roster.add_member(team, a)
	roster.add_member(team, b)
	roster.add_member(team, c)
	_check("3 members added", team.members.size() == 3)

	_check("move_member(0,2) succeeds", roster.move_member(team, 0, 2))
	_check("order after move is [b,c,a]", team.members[0] == b and team.members[1] == c and team.members[2] == a)
	_check("move_member with out-of-bounds index returns false", not roster.move_member(team, 0, 10))

	_check("remove_member(1) succeeds", roster.remove_member(team, 1))
	_check("2 members remain", team.members.size() == 2)
	_check("remove_member with out-of-bounds index returns false", not roster.remove_member(team, 99))

	roster.delete_team(team.id)

func _check_import_export(roster: TeamRosterManager) -> void:
	var team := roster.create_team("Export Me")
	var loadout := MonsterLoadout.new()
	loadout.species_id = "healslime"
	loadout.nickname = "Doc"
	loadout.equipped_skill_ids = ["heal", "sap"]
	roster.add_member(team, loadout)
	roster.save_team(team)

	var exported := roster.export_team_to_string(team)
	var imported := roster.import_team_from_string(exported)
	_check("imported team is non-null", imported != null)
	if imported != null:
		_check("imported team_name matches", imported.team_name == "Export Me")
		_check("imported gets a fresh id (not colliding with original)", imported.id != team.id)
		_check(
			"imported member fields match",
			imported.members.size() == 1
			and imported.members[0].species_id == "healslime"
			and imported.members[0].nickname == "Doc"
			and imported.members[0].equipped_skill_ids == ["heal", "sap"]
		)
		roster.delete_team(imported.id)

	var imported_preserved := roster.import_team_from_string(exported, true)
	_check("preserve_id=true keeps the original exported id", imported_preserved != null and imported_preserved.id == team.id)

	roster.delete_team(team.id)

func _check_validation(roster: TeamRosterManager, monster_db: MonsterDatabase, skillset_db: SkillSetDatabase) -> void:
	# "frizz" unlocks at 2 SP in slime's "slimer" panel; "double_slash" isn't
	# reachable from any of slime's panels at all.
	var valid_loadout := MonsterLoadout.new()
	valid_loadout.species_id = "slime"
	valid_loadout.skill_point_allocation = {"slimer": 2}
	valid_loadout.equipped_skill_ids = ["attack", "frizz"]
	_check("valid loadout has no errors", roster.validate_member(valid_loadout, monster_db, skillset_db).is_empty())

	var bad_skill_loadout := MonsterLoadout.new()
	bad_skill_loadout.species_id = "slime"
	bad_skill_loadout.equipped_skill_ids = ["double_slash"]
	_check("loadout with unknown-to-species skill flagged", roster.validate_member(bad_skill_loadout, monster_db, skillset_db).size() == 1)

	# "slimer"'s own ladder tops out at 75 SP (share_magic) -- there's no
	# separate species-wide pool, so 999 is only invalid because it overshoots
	# that panel's own top rung.
	var over_allocated_loadout := MonsterLoadout.new()
	over_allocated_loadout.species_id = "slime"
	over_allocated_loadout.skill_point_allocation = {"slimer": 999}
	_check(
		"loadout allocating past a skillset's own max rung is flagged",
		roster.validate_member(over_allocated_loadout, monster_db, skillset_db).size() == 1
	)

	var bad_species_loadout := MonsterLoadout.new()
	bad_species_loadout.species_id = "nonexistent_species"
	_check("loadout with unknown species flagged", roster.validate_member(bad_species_loadout, monster_db, skillset_db).size() == 1)

func _check_weapon_validation(roster: TeamRosterManager, monster_db: MonsterDatabase, skillset_db: SkillSetDatabase, weapon_db: WeaponDatabase) -> void:
	# Real Weapons-grid data: slime can equip sword/spear/axe/club/whip but
	# NOT claw/staff (see wiki/log.md).
	_check("WeaponDatabase loads all 110 weapons", weapon_db.get_all_weapons().size() == 110)
	var copper_sword := weapon_db.get_weapon("copper_sword")
	_check("copper_sword resolves as a sword with base_attack 10", copper_sword != null and copper_sword.weapon_type == WeaponData.Type.SWORD and copper_sword.base_attack == 10)

	var compatible_loadout := MonsterLoadout.new()
	compatible_loadout.species_id = "slime"
	compatible_loadout.equipped_weapon_id = "copper_sword"
	_check(
		"slime equipping a compatible sword has no errors",
		roster.validate_member(compatible_loadout, monster_db, skillset_db, weapon_db).is_empty()
	)

	var incompatible_loadout := MonsterLoadout.new()
	incompatible_loadout.species_id = "slime"
	incompatible_loadout.equipped_weapon_id = "stone_claws"
	_check(
		"slime equipping an incompatible claw is flagged",
		roster.validate_member(incompatible_loadout, monster_db, skillset_db, weapon_db).size() == 1
	)

	var unknown_weapon_loadout := MonsterLoadout.new()
	unknown_weapon_loadout.species_id = "slime"
	unknown_weapon_loadout.equipped_weapon_id = "nonexistent_weapon"
	_check(
		"unknown equipped_weapon_id is flagged",
		roster.validate_member(unknown_weapon_loadout, monster_db, skillset_db, weapon_db).size() == 1
	)

	_check(
		"omitting weapon_db skips weapon validation entirely (backward compatible)",
		roster.validate_member(incompatible_loadout, monster_db, skillset_db).is_empty()
	)

	# master_of_weapons bypasses equippable_weapon_types entirely, even when
	# that list is empty -- a synthetic species since no real fixture has
	# this trait yet.
	var master_species := MonsterSpecies.new()
	master_species.id = "test_master_of_weapons"
	master_species.starting_trait_ids = ["master_of_weapons"]
	master_species.equippable_weapon_types = []
	var staff := weapon_db.get_weapon("cypress_stick")
	_check("cypress_stick resolves as a staff", staff != null and staff.weapon_type == WeaponData.Type.STAFF)
	_check(
		"master_of_weapons allows equipping a staff despite an empty equippable_weapon_types",
		MonsterEquipmentRules.can_equip(master_species, staff)
	)
	_check(
		"get_equippable_weapon_types returns all 7 types for master_of_weapons",
		MonsterEquipmentRules.get_equippable_weapon_types(master_species).size() == 7
	)

func _check_malformed_import(roster: TeamRosterManager) -> void:
	var result := roster.import_team_from_string("{ this is not valid json ][")
	_check("malformed JSON import returns null without crashing", result == null)

func _contains_team_id(teams: Array[SavedTeam], team_id: String) -> bool:
	for team in teams:
		if team.id == team_id:
			return true
	return false

func _clear_test_dir() -> void:
	var dir := DirAccess.open(TEST_TEAMS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		print("FAIL: %s" % label)
		_all_passed = false
