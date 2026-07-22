class_name TraitEffect
extends Resource

## Composition base for trait behavior: every hook defaults to a no-op or
## pass-through, so a concrete trait opts into exactly the hooks it needs
## (e.g. MetalBodyTraitEffect overrides only on_before_damage_taken) instead
## of a deep per-trait subclass hierarchy.

@export var trait_data: TraitData

func on_turn_start(_ctx: BattleContext, _owner: MonsterInstance) -> void:
	pass

func on_turn_end(_ctx: BattleContext, _owner: MonsterInstance) -> void:
	pass

func on_monster_entered(_ctx: BattleContext, _owner: MonsterInstance) -> void:
	pass

func on_before_damage_dealt(_ctx: BattleContext, _owner: MonsterInstance, _target: MonsterInstance, incoming_damage: int) -> int:
	return incoming_damage

func on_before_damage_taken(_ctx: BattleContext, _owner: MonsterInstance, _attacker: MonsterInstance, incoming_damage: int) -> int:
	return incoming_damage

## Registry mapping a trait id to its concrete TraitEffect subclass. Traits
## need code (behavior), unlike skills/statuses, so this small hardcoded
## switch is the expected seam — a new trait means a new small subclass
## plus one new case here, not a data-only fixture.
static func create(id: String, data: TraitData) -> TraitEffect:
	var effect: TraitEffect
	match id:
		"metal_body":
			effect = MetalBodyTraitEffect.new()
		_:
			push_error("Unknown trait id: %s" % id)
			return null
	effect.trait_data = data
	return effect
