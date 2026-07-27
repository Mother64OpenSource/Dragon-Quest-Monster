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
## Zombie-types by a bit."). Only base_attack is mechanically wired into
## battle (see MonsterInstance._get_base_stat) -- the wide variety of
## per-weapon special effects (elemental bonus, instant death chance, HP
## restore on hit, stat boosts, breeding effects, etc.) are display-only
## flavor text for now, same honest-scoping precedent as every other
## documented-but-not-mechanically-implemented text in this project. Shown
## as a tooltip in the team builder's weapon picker.
@export var description: String = ""
