class_name SkillSetData
extends Resource

## A skill panel: an ordered ladder of thresholds unlocked by investing skill
## points. Two threshold kinds:
##   {"sp": int, "kind": "skill", "skill_id": String}
##   {"sp": int, "kind": "stat_boost", "stat_name": String, "amount": int}
## Passive perks/wards/traits from the source data that don't map to either
## kind are omitted entirely (not yet modeled -- see wiki/log.md).
##
## stat_boost thresholds are tracked as real data but not yet applied to
## battle stats -- there is no MonsterLoadout -> MonsterInstance bridge in
## the engine yet (species stats are read directly), so wiring stat boosts
## into actual battle math is a separate follow-up.

@export var id: String = ""
@export var display_name: String = ""
@export var thresholds: Array[Dictionary] = []

## Skill ids only (stat_boost thresholds excluded), sorted by sp ascending.
func get_skill_thresholds() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for t in thresholds:
		if t.get("kind") == "skill":
			result.append(t)
	return result

## Every skill_id unlockable at or below the given point investment.
func unlocked_skill_ids(points: int) -> Array[String]:
	var result: Array[String] = []
	for t in thresholds:
		if t.get("kind") == "skill" and int(t.get("sp", 0)) <= points:
			result.append(t["skill_id"])
	return result
