class_name BlacksmithItemData
extends Resource

## Static per-item data for a craftable Blacksmith bonus. Sourced from the
## source spreadsheet's "Blacksmith" tab. Unlike WeaponData, these are
## permanent bonuses applied directly to a specific monster (see
## MonsterLoadout.crafted_blacksmith_ids), not equipped gear.
##
## The source data gates each item behind crafting materials (gathered from
## shops/monster drops) -- this engine has no inventory, currency, or
## item-drop-tracking system at all (see wiki/log.md), so materials_text is
## flavor-only: applying a Blacksmith bonus in the team builder is free and
## unlimited, not gated by any resource cost. An honest simplification, same
## convention as every other invented/simplified mechanic in this project.

enum Category { STAT_BOOST, TRAIT_GRANT }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var materials_text: String = ""
@export var category: Category = Category.STAT_BOOST

## STAT_BOOST only: which base stat ("attack"/"defense"/"agility"/"wisdom")
## and how much flat bonus (a real sourced number, e.g. "+20").
@export var stat_name: String = ""
@export var flat_bonus: int = 0

## TRAIT_GRANT only: a real id that already exists in TraitDatabase -- the
## exact same trait some monsters carry innately (e.g. "critical_massacre"
## is also Slime's own starting trait). Granting one of these to a monster
## that already has it innately is a no-op (see MonsterEquipmentRules-style
## dedup in TeamToBattleBridge), matching the source text's own "has no
## effect on those who already have that bonus" caveat.
@export var granted_trait_id: String = ""
