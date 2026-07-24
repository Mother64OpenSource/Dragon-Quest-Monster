class_name TeamFormationLayout
extends RefCounted

## Splits a team's ordered member list into a Main Party (the active
## battle lineup) and a Second Party (the bench), each capped at
## PARTY_CAPACITY slot-points -- a 2-slot monster costs 2, a 4-slot
## monster costs 4, etc. Mirrors BattleSetup._send_out_side()'s real
## greedy packing exactly (skip a member that doesn't fit the remaining
## budget, keep scanning in case a smaller one further down does fit, stop
## trying once the budget is fully used) so the team builder's "Main
## Party" preview always matches who actually deploys active in battle.
## Applied a second time to whatever's left over for the Second Party,
## which the engine itself never previously capped -- this is a
## team-builder-side rule, not a change to BattleSetup/FaintHandler.
##
## Anything that doesn't fit in EITHER party ends up in "overflow" --
## should never happen for a team built by only ever adding through
## TeamEditorPanel (which validates before adding), but reordering an
## already-saved team can, in principle, surface it depending on order
## (see wiki/log.md); callers surface that as a validation issue rather
## than silently dropping members.

const PARTY_CAPACITY := 4

static func compute(members: Array[MonsterLoadout], monster_db: MonsterDatabase) -> Dictionary:
	var main_party: Array[MonsterLoadout] = []
	var leftover: Array[MonsterLoadout] = []
	var main_used := _pack(members, monster_db, main_party, leftover)

	var second_party: Array[MonsterLoadout] = []
	var overflow: Array[MonsterLoadout] = []
	var second_used := _pack(leftover, monster_db, second_party, overflow)

	return {
		"main_party": main_party,
		"main_used": main_used,
		"second_party": second_party,
		"second_used": second_used,
		"overflow": overflow,
	}

static func _pack(members: Array[MonsterLoadout], monster_db: MonsterDatabase, fit: Array[MonsterLoadout], rest: Array[MonsterLoadout]) -> int:
	var used := 0
	for member in members:
		if used >= PARTY_CAPACITY:
			rest.append(member)
			continue
		var species := monster_db.get_species(member.species_id)
		var cost := species.slots if species != null else 1
		if used + cost > PARTY_CAPACITY:
			rest.append(member)
			continue
		fit.append(member)
		used += cost
	return used
