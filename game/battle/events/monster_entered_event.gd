class_name MonsterEnteredEvent
extends BattleEvent

var instance_id: int
var species_id: String
var side: String
var slot: int

func _init(p_instance_id: int, p_species_id: String, p_side: String, p_slot: int) -> void:
	instance_id = p_instance_id
	species_id = p_species_id
	side = p_side
	slot = p_slot

func get_event_type() -> String:
	return "monster_entered"

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["instance_id"] = instance_id
	d["species_id"] = species_id
	d["side"] = side
	d["slot"] = slot
	return d
