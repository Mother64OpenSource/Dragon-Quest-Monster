class_name SkillLoader
extends RefCounted

## Builds a SkillData from a parsed JSON dict. status_registry maps
## status id (String) -> StatusData, already loaded, so StatusEffect can hold
## a direct resource reference instead of a runtime id lookup.
static func load_from_dict(data: Dictionary, status_registry: Dictionary) -> SkillData:
	var skill := SkillData.new()
	skill.id = data.get("id", "")
	skill.display_name = data.get("display_name", skill.id)
	skill.description = data.get("description", "")
	skill.mp_cost = int(data.get("mp_cost", 0))
	skill.priority = int(data.get("priority", 0))
	skill.accuracy = float(data.get("accuracy", 1.0))
	skill.category = _parse_category(data.get("category", "physical"))
	skill.target_type = _parse_target_type(data.get("target_type", "single_enemy"))
	skill.element = data.get("element", "")
	skill.skill_type = data.get("skill_type", "")

	var effects: Array[SkillEffect] = []
	for effect_data in data.get("effects", []):
		var effect := _build_effect(effect_data, status_registry)
		if effect != null:
			if effect is DamageEffect or effect is StatModEffect:
				effect.element = skill.element
			if effect is DamageEffect:
				effect.skill_type = skill.skill_type
			effects.append(effect)
	skill.effects = effects
	return skill

static func load_from_file(path: String, status_registry: Dictionary) -> SkillData:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("Failed to parse skill JSON: %s" % path)
		return null
	return load_from_dict(parsed, status_registry)

static func _parse_category(value: String) -> SkillData.Category:
	match value:
		"physical":
			return SkillData.Category.PHYSICAL
		"magic":
			return SkillData.Category.MAGIC
		"status":
			return SkillData.Category.STATUS
		_:
			push_error("Unknown skill category: %s" % value)
			return SkillData.Category.PHYSICAL

static func _parse_target_type(value: String) -> SkillData.TargetType:
	match value:
		"self":
			return SkillData.TargetType.SELF
		"single_enemy":
			return SkillData.TargetType.SINGLE_ENEMY
		_:
			push_error("Unknown skill target type: %s" % value)
			return SkillData.TargetType.SINGLE_ENEMY

static func _parse_turn_order_mode(value: String) -> TurnOrderOverrideEffect.Mode:
	match value:
		"shuffle":
			return TurnOrderOverrideEffect.Mode.SHUFFLE
		"reverse":
			return TurnOrderOverrideEffect.Mode.REVERSE
		_:
			push_error("Unknown turn_order_override mode: %s" % value)
			return TurnOrderOverrideEffect.Mode.SHUFFLE

static func _parse_damage_category(value: String) -> DamageEffect.Category:
	match value:
		"physical":
			return DamageEffect.Category.PHYSICAL
		"magic":
			return DamageEffect.Category.MAGIC
		_:
			push_error("Unknown damage category: %s" % value)
			return DamageEffect.Category.PHYSICAL

static func _build_effect(effect_data: Dictionary, status_registry: Dictionary) -> SkillEffect:
	var effect_type: String = effect_data.get("type", "")
	match effect_type:
		"damage":
			var effect := DamageEffect.new()
			effect.category = _parse_damage_category(effect_data.get("category", "physical"))
			effect.power = int(effect_data.get("power", 0))
			effect.min_hits = int(effect_data.get("min_hits", 1))
			effect.max_hits = int(effect_data.get("max_hits", effect.min_hits))
			return effect
		"heal":
			var effect := HealEffect.new()
			effect.power = int(effect_data.get("power", 0))
			effect.percent_max_hp = float(effect_data.get("percent_max_hp", 0.0))
			effect.target_self = bool(effect_data.get("target_self", true))
			return effect
		"status":
			var effect := StatusEffect.new()
			var status_id: String = effect_data.get("status_id", "")
			effect.status_data = status_registry.get(status_id)
			if effect.status_data == null:
				push_error("Unknown status_id referenced in skill effect: %s" % status_id)
			effect.chance = float(effect_data.get("chance", 1.0))
			effect.target_self = bool(effect_data.get("target_self", false))
			return effect
		"stat_mod":
			var effect := StatModEffect.new()
			effect.stat_name = effect_data.get("stat_name", "attack")
			effect.stages = int(effect_data.get("stages", 1))
			effect.chance = float(effect_data.get("chance", 1.0))
			effect.target_self = bool(effect_data.get("target_self", true))
			return effect
		"cure_status":
			var effect := CureStatusEffect.new()
			var status_ids: Array[String] = []
			for status_id in effect_data.get("status_ids", []):
				status_ids.append(str(status_id))
			effect.status_ids = status_ids
			effect.target_self = bool(effect_data.get("target_self", true))
			return effect
		"restore_mp":
			var effect := RestoreMpEffect.new()
			effect.power = int(effect_data.get("power", 0))
			effect.percent_max_mp = float(effect_data.get("percent_max_mp", 0.0))
			effect.target_self = bool(effect_data.get("target_self", true))
			return effect
		"turn_order_override":
			var effect := TurnOrderOverrideEffect.new()
			effect.mode = _parse_turn_order_mode(effect_data.get("mode", "shuffle"))
			return effect
		"taunt":
			return TauntEffect.new()
		_:
			push_error("Unknown skill effect type: %s" % effect_type)
			return null
