class_name MonsterDatabase
extends RefCounted

## Real, reusable species registry — replaces the throwaway loading logic
## that used to live directly in the test fixture. Loads once at
## construction; species data is read-only fixture/production data.

const DEFAULT_FIXTURES_DIR := "res://database/monsters/fixtures"

var species_by_id: Dictionary = {}

func _init(source_dir: String = DEFAULT_FIXTURES_DIR) -> void:
	for path in JsonDirLoader.list_json_files(source_dir):
		var species := MonsterLoader.load_from_file(path)
		if species != null:
			species_by_id[species.id] = species

func get_species(id: String) -> MonsterSpecies:
	return species_by_id.get(id)

func get_all_species() -> Array[MonsterSpecies]:
	var result: Array[MonsterSpecies] = []
	for species in species_by_id.values():
		result.append(species)
	return result

func search_by_name(query: String) -> Array[MonsterSpecies]:
	var lowered_query := query.to_lower()
	var result: Array[MonsterSpecies] = []
	for species in get_all_species():
		if species.id.to_lower().contains(lowered_query) or species.display_name.to_lower().contains(lowered_query):
			result.append(species)
	return result

func filter_by_rank(rank: MonsterSpecies.Rank) -> Array[MonsterSpecies]:
	var result: Array[MonsterSpecies] = []
	for species in get_all_species():
		if species.rank == rank:
			result.append(species)
	return result

func filter_by_family(family: String) -> Array[MonsterSpecies]:
	var lowered_family := family.to_lower()
	var result: Array[MonsterSpecies] = []
	for species in get_all_species():
		if species.family.to_lower() == lowered_family:
			result.append(species)
	return result

## Combined AND filter — each axis is optional: an empty name_query/family or
## a null rank skips that axis entirely.
func find(name_query: String = "", rank: Variant = null, family: String = "") -> Array[MonsterSpecies]:
	var lowered_query := name_query.to_lower()
	var lowered_family := family.to_lower()
	var result: Array[MonsterSpecies] = []
	for species in get_all_species():
		if not name_query.is_empty():
			if not (species.id.to_lower().contains(lowered_query) or species.display_name.to_lower().contains(lowered_query)):
				continue
		if rank != null and species.rank != rank:
			continue
		if not family.is_empty() and species.family.to_lower() != lowered_family:
			continue
		result.append(species)
	return result
