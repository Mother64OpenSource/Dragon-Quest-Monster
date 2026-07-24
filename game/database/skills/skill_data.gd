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
