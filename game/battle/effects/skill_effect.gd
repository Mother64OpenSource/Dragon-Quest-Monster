class_name SkillEffect
extends Resource

## Composition point for SkillData: a skill's behavior is entirely the sum of
## the SkillEffect resources in its effects array, applied in order. New
## skill behavior should mean a new combination of existing effects, or
## occasionally a new small SkillEffect subclass — never a new SkillData
## subtype.

func apply(_ctx: BattleContext, _user: MonsterInstance, _target: MonsterInstance) -> void:
	push_error("SkillEffect.apply() not implemented by %s" % get_script().resource_path)
