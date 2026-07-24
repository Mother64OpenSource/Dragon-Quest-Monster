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

## Added to the acting monster's skill-priority sort key in ActionResolver --
## a large enough constant overrides raw agility entirely (Early Bird/Last
## Word/Ultra Fast Action), a small one nudges it.
func get_priority_bonus() -> int:
	return 0

## Multiplies the base crit chance for a hit this monster (owner) deals of
## the given category (DamageEffect.Category). 1.0 = no change.
func get_crit_chance_multiplier(_owner: MonsterInstance, _category: int) -> float:
	return 1.0

## True vetoes a crit that would otherwise land on this monster (Full
## Satisfaction Guard).
func blocks_critical_hits() -> bool:
	return false

## Fires on the target after a hit is confirmed critical AND actually dealt
## damage (a dodged/fully-negated crit never "landed," so this doesn't fire
## for one -- see DamageEffect.apply()).
func on_critical_hit_taken(_ctx: BattleContext, _owner: MonsterInstance, _attacker: MonsterInstance) -> void:
	pass

## Multiplies this monster's own accuracy when it's the actor (Hopeful
## Hitter trades accuracy for crit chance). 1.0 = no change.
func get_accuracy_multiplier() -> float:
	return 1.0

## Registry mapping a trait id to its concrete TraitEffect subclass. Traits
## need code (behavior), unlike skills/statuses, so this small hardcoded
## switch is the expected seam — a new trait means a new small subclass
## plus one new case here, not a data-only fixture.
##
## Most real trait names (dodge/crit/counter/turn-order/flee/tension/etc.)
## describe mechanics this battle engine has no subsystem for at all. Rather
## than erroring for every one of those at battle setup, an id with valid
## TraitData but no case below falls through to a plain no-op TraitEffect --
## it's still real, inspectable TraitData (shows up in UI), it just has no
## behavior. Only ids naming an actually-modeled mechanic get a concrete
## subclass.
static func create(id: String, data: TraitData) -> TraitEffect:
	var effect: TraitEffect
	match id:
		"metal_body":
			effect = MetalBodyTraitEffect.new()
		"light_metal_body":
			effect = DamageReductionTraitEffect.new()
			effect.damage_reduction_percent = 0.5
		"hard_metal_body":
			effect = DamageReductionTraitEffect.new()
			effect.damage_reduction_percent = 0.75
		"superhard_metal_body":
			effect = DamageReductionTraitEffect.new()
			effect.damage_reduction_percent = 0.8
		"steady_recovery":
			effect = TurnEndHpDeltaTraitEffect.new()
			effect.percent_of_max = 0.06
		"magic_regenerator":
			effect = TurnEndMpDeltaTraitEffect.new()
			effect.percent_of_max = 0.1
		"disenchanted":
			effect = TurnEndMpDeltaTraitEffect.new()
			effect.percent_of_max = -0.08
		"hunter_mech":
			effect = BonusDamageVsMetalBodyTraitEffect.new()
			effect.flat_bonus = 1
		"early_bird":
			effect = PriorityBonusTraitEffect.new()
			effect.priority_bonus = 100
		"ultra_fast_action":
			effect = PriorityBonusTraitEffect.new()
			effect.priority_bonus = 200
		"last_word":
			effect = PriorityBonusTraitEffect.new()
			effect.priority_bonus = -100
		"critical_massacre":
			effect = CritChanceMultiplierTraitEffect.new()
			effect.multiplier = 2.0
			effect.category_filter = -1
		"spell_satisfaction":
			effect = CritChanceMultiplierTraitEffect.new()
			effect.multiplier = 2.0
			effect.category_filter = DamageEffect.Category.MAGIC
		"desperado":
			effect = DesperadoTraitEffect.new()
		"hopeful_hitter":
			effect = HopefulHitterTraitEffect.new()
		"full_satisfaction_guard":
			effect = FullSatisfactionGuardTraitEffect.new()
		"artful_dodger":
			effect = ChanceBasedDamageNegationTraitEffect.new()
			effect.chance = 0.15
			effect.blocked_by_trait_id = "fly_swatter"
		"perilous_parrier":
			effect = ChanceBasedDamageNegationTraitEffect.new()
			effect.chance = 0.5
			effect.damage_multiplier_otherwise = 1.5
		"counter_striker":
			effect = CounterAttackTraitEffect.new()
			effect.counter_chance = 0.25
			effect.also_negates_damage = false
		"perfect_parry":
			effect = CounterAttackTraitEffect.new()
			effect.counter_chance = 0.25
			effect.also_negates_damage = true
		"gamble_counter":
			effect = CounterAttackTraitEffect.new()
			effect.counter_chance = 1.0
			effect.also_negates_damage = false
		"sudden_tension", "random_tension":
			effect = ChanceBasedTensionGainTraitEffect.new()
			effect.chance = 0.15
			effect.levels = 1
		"rare_high_tension":
			effect = ChanceBasedTensionGainTraitEffect.new()
			effect.chance = 0.05
			effect.levels = 2
		"wrath_of_the_stars", "one_shot_reversal":
			effect = HpGatedTensionJumpTraitEffect.new()
			effect.hp_threshold_percent = 0.25
			effect.target_level = 4
		"heat_up":
			effect = HeatUpTraitEffect.new()
		_:
			effect = TraitEffect.new()
	effect.trait_data = data
	return effect
