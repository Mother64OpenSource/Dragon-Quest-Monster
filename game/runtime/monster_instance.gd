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

## null means no weapon equipped. Set at battle-bridge time from the
## loadout's equipped_weapon_id (see TeamToBattleBridge.build_team) --
## compatibility with the species is enforced earlier, at team-builder
## time (TeamRosterManager.validate_member), not here.
var equipped_weapon: WeaponData = null

## Resolved STAT_BOOST BlacksmithItemData this monster has crafted (see
## TeamToBattleBridge.build_team) -- permanent, unlike equipped_weapon,
## and there can be more than one (e.g. both an ATK and a DEF boost).
var crafted_stat_boosts: Array[BlacksmithItemData] = []

## Tension: a one-directional escalating counter (0-4), not a StatStages-style
## symmetric stage -- each level boosts this monster's own next damage-
## dealing action, then resets to 0 (see DamageEffect.apply()).
var tension_level: int = 0

## Set by a Defend action, cleared the moment this monster's own next
## action executes (whatever it is) -- see ActionExecutor.execute(). Halves
## incoming damage while true (DamageEffect._run_damage_hooks()), matching
## the real DQ "Defend" command's "lasts until your next turn" duration.
var is_defending: bool = false

## Set by TauntEffect (Selflessness et al.), cleared the moment this
## monster's own next action executes -- same "until your next turn"
## lifetime as is_defending, see ActionExecutor.execute(). While true,
## every SINGLE_ENEMY skill the opposing side uses gets redirected to this
## monster regardless of what target was actually picked (see
## ActionExecutor.execute() and BattleState.get_taunting_monster()), and
## incoming damage is increased rather than reduced
## (DamageEffect._run_damage_hooks()) -- "takes damage instead of an ally,
## but takes significantly more of it."
var is_taunting: bool = false

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
			var weapon_bonus := equipped_weapon.base_attack if equipped_weapon != null else 0
			return species.base_attack + weapon_bonus + _crafted_flat_bonus("attack")
		"defense":
			return _with_weapon_stat_bonus(species.base_defense, "defense") + _crafted_flat_bonus("defense")
		"agility":
			return _with_weapon_stat_bonus(species.base_agility, "agility") + _crafted_flat_bonus("agility")
		"wisdom":
			return _with_weapon_stat_bonus(species.base_wisdom, "wisdom") + _crafted_flat_bonus("wisdom")
		_:
			push_error("Unknown stat name: %s" % stat_name)
			return 0

## Weapon secondary stat bonuses (WeaponData.bonus_stats) are a percentage of
## the species' own base stat -- see WeaponData's own doc comment for why a
## percentage rather than a flat number.
func _with_weapon_stat_bonus(base_value: int, stat_name: String) -> int:
	if equipped_weapon == null or not equipped_weapon.bonus_stats.has(stat_name):
		return base_value
	var percent: float = equipped_weapon.bonus_stats[stat_name]
	return base_value + MathUtils.round_half_up(float(base_value) * percent)

## Blacksmith stat-boost items are a real flat number from the source text
## (unlike weapons' invented percentages) -- summed if more than one applies.
func _crafted_flat_bonus(stat_name: String) -> int:
	var total := 0
	for item in crafted_stat_boosts:
		if item.stat_name == stat_name:
			total += item.flat_bonus
	return total
