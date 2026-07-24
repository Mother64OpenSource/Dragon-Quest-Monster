class_name MonsterInstance
extends RefCounted

## Mutable per-battle runtime state for one monster. Referenced everywhere
## else (events, actions) by instance_id, never by object reference, so the
## battle log stays serializable.

var instance_id: int
var species: MonsterSpecies
var side: String
var slot: int

var current_hp: int
var current_mp: int
var stat_stages: StatStages
var active_status: StatusInstance = null
var active_traits: Array[TraitEffect] = []
var learned_skills: Array[SkillData] = []
var has_been_processed_as_fainted: bool = false

## Tension: a one-directional escalating counter (0-4), not a StatStages-style
## symmetric stage -- each level boosts this monster's own next damage-
## dealing action, then resets to 0 (see DamageEffect.apply()).
var tension_level: int = 0

## Set by a Defend action, cleared the moment this monster's own next
## action executes (whatever it is) -- see ActionExecutor.execute(). Halves
## incoming damage while true (DamageEffect._run_damage_hooks()), matching
## the real DQ "Defend" command's "lasts until your next turn" duration.
var is_defending: bool = false

func _init(p_instance_id: int, p_species: MonsterSpecies, p_side: String, p_slot: int) -> void:
	instance_id = p_instance_id
	species = p_species
	side = p_side
	slot = p_slot
	current_hp = p_species.base_hp
	current_mp = p_species.base_mp
	stat_stages = StatStages.new()

func is_fainted() -> bool:
	return current_hp <= 0

## Returns actual HP lost (clamped to [0, max_hp]).
func take_damage(amount: int) -> int:
	var before := current_hp
	current_hp = clampi(current_hp - amount, 0, species.base_hp)
	return before - current_hp

## Returns actual HP restored (clamped to [0, max_hp]).
func heal(amount: int) -> int:
	var before := current_hp
	current_hp = clampi(current_hp + amount, 0, species.base_hp)
	return current_hp - before

func get_effective_stat(stat_name: String) -> int:
	var base_value := _get_base_stat(stat_name)
	var multiplier := StatStages.stage_multiplier(stat_stages.get_stage(stat_name))
	return maxi(1, MathUtils.round_half_up(float(base_value) * multiplier))

func apply_stat_stage(stat_name: String, delta: int) -> int:
	return stat_stages.modify(stat_name, delta)

func _get_base_stat(stat_name: String) -> int:
	match stat_name:
		"attack":
			return species.base_attack
		"defense":
			return species.base_defense
		"agility":
			return species.base_agility
		"wisdom":
			return species.base_wisdom
		_:
			push_error("Unknown stat name: %s" % stat_name)
			return 0
