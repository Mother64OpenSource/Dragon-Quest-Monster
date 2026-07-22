class_name BattleEndedEvent
extends BattleEvent

var winner_side: String

func _init(p_winner_side: String) -> void:
	winner_side = p_winner_side

func get_event_type() -> String:
	return "battle_ended"

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["winner_side"] = winner_side
	return d
