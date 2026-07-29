class_name SkillSetData
extends Resource

## A skill panel: an ordered ladder of thresholds unlocked by investing skill
## points. Three threshold kinds:
##   {"sp": int, "kind": "skill", "skill_id": String}
##   {"sp": int, "kind": "trait", "trait_id": String}
##   {"sp": int, "kind": "stat_boost", "stat_name": String, "amount": int}
## (e.g. Diamond Slime's own 120/150 SP rungs are Steady Recovery/Magic
## Regenerator -- real traits, not skills -- see wiki/log.md.)
##
## stat_boost thresholds are tracked as real data but not yet applied to
## battle stats -- TeamToBattleBridge doesn't fold them into a bridged
## MonsterInstance's stats at all yet, unlike skill/trait thresholds (see
## TeamRosterManager.get_unlocked_skill_ids/get_active_trait_ids), so wiring
## them into actual battle math is a separate follow-up.

@export var id: String = ""
@export var display_name: String = ""
@export var thresholds: Array[Dictionary] = []

## Skill ids only (stat_boost/trait thresholds excluded), sorted by sp ascending.
func get_skill_thresholds() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for t in thresholds:
		if t.get("kind") == "skill":
			result.append(t)
	return result

## Trait ids only (stat_boost/skill thresholds excluded), sorted by sp ascending.
func get_trait_thresholds() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for t in thresholds:
		if t.get("kind") == "trait":
			result.append(t)
	return result

## Every skill_id unlockable at or below the given point investment.
func unlocked_skill_ids(points: int) -> Array[String]:
	var result: Array[String] = []
	for t in thresholds:
		if t.get("kind") == "skill" and int(t.get("sp", 0)) <= points:
			result.append(t["skill_id"])
	return result

## Every trait_id unlockable at or below the given point investment.
func unlocked_trait_ids(points: int) -> Array[String]:
	var result: Array[String] = []
	for t in thresholds:
		if t.get("kind") == "trait" and int(t.get("sp", 0)) <= points:
			result.append(t["trait_id"])
	return result

## The top rung of this panel's own ladder -- the real, sourced cap on how
## many points can usefully go into this one skillset, independent of any
## other panel (there's no shared cross-panel point pool; skill points are
## effectively unlimited via farmable skill seeds, see wiki/log.md).
func max_sp() -> int:
	var result := 0
	for t in thresholds:
		result = maxi(result, int(t.get("sp", 0)))
	return result
