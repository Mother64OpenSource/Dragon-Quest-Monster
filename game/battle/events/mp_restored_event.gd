class_name MpRestoredEvent
extends BattleEvent

## Mirrors HealingAppliedEvent's own shape, for MP instead of HP (Magic
## Multiplier, Sonata of Serenity). Deliberately not MpDrainEvent, which is
## specifically for stealing MP from another monster (Take Magic/Drain
## Magic Attack) -- this is a monster restoring its own supply, the MP
## equivalent of a heal.

var source_instance_id: int
var target_instance_id: int
var amount: int
var resulting_mp: int

func _init(p_source_instance_id: int, p_target_instance_id: int, p_amount: int, p_resulting_mp: int) -> void:
	source_instance_id = p_source_instance_id
	target_instance_id = p_target_instance_id
	amount = p_amount
	resulting_mp = p_resulting_mp

func get_event_type() -> String:
	return "mp_restored"

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["source_instance_id"] = source_instance_id
	d["target_instance_id"] = target_instance_id
	d["amount"] = amount
	d["resulting_mp"] = resulting_mp
	return d
