class_name SkillData
extends Resource

enum Category { PHYSICAL, MAGIC, STATUS }
enum TargetType { SELF, SINGLE_ENEMY }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var mp_cost: int = 0
@export var priority: int = 0
@export var accuracy: float = 1.0
@export var category: Category = Category.PHYSICAL
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var effects: Array[SkillEffect] = []
## Real elemental attribute from the source data (e.g. "Frizz", "Zap",
## "Fire Breath") -- empty for skills with no elemental identity (a plain
## physical Attack, a stat buff, etc.). Also mirrored onto each of this
## skill's own DamageEffect entries at load time (see SkillLoader), since a
## damage hook only ever sees the DamageEffect it's firing from, not the
## parent SkillData.
@export var element: String = ""
## Real "Type" column from the source data (Spell/Slash/Body/Dance/Breath/
## Other) -- a coarser, orthogonal breakdown from `element`/`category`
## (e.g. Frizz and Zap are both "Spell", Attack and Hatchet Man are both
## "Slash"). Empty for the handful of M1 hand-tuned skills with no
## spreadsheet match. Also mirrored onto each of this skill's own
## DamageEffect entries at load time (see SkillLoader), same reasoning as
## `element`.
@export var skill_type: String = ""
