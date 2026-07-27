class_name WeaponData
extends Resource

## Static per-weapon data, shared/read-only across every MonsterInstance
## that has one equipped. Sourced from the source spreadsheet's "Items"
## tab (Uses/Equipment section, No. 306-415) -- see wiki/log.md.

enum Type { SWORD, SPEAR, AXE, CLUB, WHIP, CLAW, STAFF }

## String ids in the same order as the Type enum -- the same ids used by
## MonsterSpecies.equippable_weapon_types (sourced from the Monsters sheet's
## Weapons compatibility grid columns Swo/Spe/Axe/Ham/Whip/Claw/Staff).
const ALL_TYPE_IDS: Array[String] = ["sword", "spear", "axe", "club", "whip", "claw", "staff"]

@export var id: String = ""
@export var display_name: String = ""
@export var weapon_type: Type = Type.SWORD
@export var base_attack: int = 0

## Full flavor text from the source sheet (e.g. "Increase damage against
## Zombie-types by a bit."). Shown as a tooltip in the team builder's
## weapon picker. Some of this text is now mechanically backed by the
## fields below; the rest (instant-death chance, breeding effects, EXP/Gold/
## skill-point multipliers, "attack all enemies," item/scout/Break/Tension-
## drain procs) stays display-only -- same honest-scoping precedent as
## every other documented-but-not-mechanically-implemented text in this
## project (see wiki/log.md for exactly which effects got wired up and
## which didn't, and why).
@export var description: String = ""

## Bonus damage against a target whose MonsterSpecies.family (matched
## case-insensitively -- fixture casing isn't fully consistent, see
## wiki/log.md) is in this list, e.g. ["Dragon"] or ["Beast", "Nature"] for
## the handful of weapons that name two families at once. Magnitude tiers
## sourced from the sheet's own adverbs ("by a bit"/"some"/plain/"by a
## lot"/"significantly") but the actual multiplier values are invented
## placeholders, same convention as every other numeric constant in this
## project -- see DamageEffect for the exact tier mapping.
@export var bonus_vs_families: Array[String] = []
@export var bonus_damage_multiplier: float = 1.0

## Flat bonus specifically against a target with any metal-body trait
## active -- checked via traits, not species.family, mirroring
## BonusDamageVsMetalBodyTraitEffect's own reasoning (Metal Slime is
## species family "Slime" but carries a metal_body trait). Covers the
## sheet's "+N damage when attacking Metal-types" weapons.
@export var bonus_vs_metal_body_flat: int = 0

## Multiplies this weapon's wielder's crit chance the same way
## TraitEffect.get_crit_chance_multiplier() does. category_filter mirrors
## CritChanceMultiplierTraitEffect's own field: -1 = both physical and
## magic, else restricts to one DamageEffect.Category (e.g. Magical Whip's
## "chance of SPELL critical" is magic-only).
@export var crit_chance_multiplier: float = 1.0
@export var crit_chance_category_filter: int = -1

## Secondary stat bonus beyond base_attack, e.g. {"wisdom": 0.1} for a 10%
## Wisdom boost. Keyed by stat name ("agility"/"wisdom"/"defense"), applied
## as a percentage of the wielder's own base stat (no flat number exists in
## the source text for these, unlike base_attack's explicit "+N" -- a
## percentage scales sensibly across this game's very wide stat range,
## roughly 10 to 1500+, better than any single invented flat number would).
@export var bonus_stats: Dictionary = {}

## Heals the wielder this percentage of damage dealt on every connecting
## hit (e.g. Miracle Sword's "Restores HP.", no magnitude given in the
## source text -- an invented placeholder like every other undocumented
## numeric constant here).
@export var lifesteal_percent: float = 0.0
