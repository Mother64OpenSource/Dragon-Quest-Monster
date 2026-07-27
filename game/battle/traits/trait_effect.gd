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

## element is the hit's own DamageEffect.element ("Frizz", "Zap", ... or ""
## for a non-elemental hit like a plain physical Attack) -- threaded through
## so an elemental-boost trait (a -meister/crafty_X trait) can check what
## element this specific hit is before deciding whether to apply at all.
func on_before_damage_dealt(_ctx: BattleContext, _owner: MonsterInstance, _target: MonsterInstance, incoming_damage: int, _element: String = "") -> int:
	return incoming_damage

## Same element parameter, same reasoning, for the receiving side (a Ward
## trait needs to know what element it's resisting).
func on_before_damage_taken(_ctx: BattleContext, _owner: MonsterInstance, _attacker: MonsterInstance, incoming_damage: int, _element: String = "") -> int:
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

## Extra full repeats of this monster's queued action this turn, on top of
## the one it already gets (Hit Squad). Each repeat is a completely separate
## ActionExecutor.execute() call -- its own accuracy roll, MP cost, crit
## roll, everything -- not just an extra hit within one skill's own effects
## (that's DamageEffect.min_hits/max_hits, a different, already-existing
## mechanic for a single skill hitting more than once). 0 = no change.
func get_extra_attack_count() -> int:
	return 0

## True caps an otherwise-lethal hit at 1 HP instead (Close Scraper/Endure)
## -- checked in DamageEffect.apply() only when the incoming hit would
## actually reduce this monster to 0 or below, right before it's applied.
func survives_lethal_hit(_ctx: BattleContext, _owner: MonsterInstance) -> bool:
	return false

## Multiplies this monster's own MP cost for the given skill it's about to
## use (Magic Miser/Magic Scrooge reduce it unconditionally; Spell
## Splurger, the Guard Break pair, and Crafty Devil raise it, some of those
## paired with a damage boost via on_before_damage_dealt; a -meister/
## crafty_X trait only discounts skills matching its own element). Read in
## ActionExecutor.execute() for both the insufficient-MP fizzle check and
## the real deduction, so a discount/surcharge is never observable in one
## but not the other. 1.0 = no change.
func get_mp_cost_multiplier(_skill: SkillData) -> float:
	return 1.0

## Multiplies the chance a status this monster (owner) is about to inflict
## AS THE ATTACKER actually lands (a crafty_X trait, e.g. Crafty Poisoner).
## Read from the user's traits inside StatusEffect.apply(), keyed by the
## status about to be applied (StatusData.id). 1.0 = no change.
func get_status_infliction_multiplier(_status_id: String) -> float:
	return 1.0

## Multiplies the chance a status is about to land ON this monster (owner)
## AS THE RECIPIENT (a Ward trait, e.g. Poison Ward). Read from the
## recipient's traits inside StatusEffect.apply(), same status_id keying.
## 1.0 = no change.
func get_status_resistance_multiplier(_status_id: String) -> float:
	return 1.0

## Same idea as get_status_infliction_multiplier, but for a stat-debuff
## SkillEffect (StatModEffect) instead of a StatusEffect -- keyed by
## StatModEffect.element (e.g. "Sag", "Sap", "Decelerate") rather than a
## StatusData id, since a stat debuff isn't a "status" in this engine's own
## model. Read from the user's traits inside StatModEffect.apply(). 1.0 =
## no change.
func get_stat_mod_infliction_multiplier(_element: String) -> float:
	return 1.0

## Same idea as get_status_resistance_multiplier, for a stat-debuff
## SkillEffect. Read from the recipient's traits inside StatModEffect.apply().
## 1.0 = no change.
func get_stat_mod_resistance_multiplier(_element: String) -> float:
	return 1.0

## Multiplies the amount a HealEffect this monster (owner) casts actually
## restores (Health Professional). Read from the caster's (user's) traits
## inside HealEffect.apply(). 1.0 = no change.
func get_heal_multiplier() -> float:
	return 1.0

## Multiplies damage this monster (owner) deals with a skill of the given
## Type (Spell/Slash/Body/Dance/Breath/Other -- SkillData.skill_type/
## DamageEffect.skill_type, a coarser, orthogonal breakdown from `element`).
## Read from the user's traits inside DamageEffect._run_damage_hooks(),
## chained onto the same running damage total as on_before_damage_dealt.
## 1.0 = no change.
func get_skill_type_damage_multiplier(_skill_type: String) -> float:
	return 1.0

## Chance this monster (owner) simply fails to act on its own turn, for
## personality reasons rather than a status condition (Timid, Yellow Belly,
## Foot Dragger). Checked in ActionExecutor.execute() alongside (but
## structurally separate from) the existing status-driven skip_turn_chance.
## 0.0 (the default) means the check is skipped entirely -- no roll, no new
## RNG draw -- so a monster without one of these traits behaves exactly as
## before.
func get_self_skip_turn_chance() -> float:
	return 0.0

## Fires on this monster (owner) right after a status is successfully
## applied to it via StatusEffect.apply() (Tit for Tat) -- NOT for a status
## applied by a retaliation/entry trait, which construct StatusInstance
## directly rather than going through StatusEffect.apply() at all.
## inflicter is whoever cast the status (may equal owner for a self-applied
## status, e.g. a debuff skill with target_self=true).
func on_status_afflicted(_ctx: BattleContext, _owner: MonsterInstance, _inflicter: MonsterInstance, _status_data: StatusData) -> void:
	pass

## Multiplies this monster's own TENSION_DAMAGE_PERCENT_PER_LEVEL (Dust of
## the Clan's "chance of 2x Tension Burn"). Computed once per action inside
## DamageEffect.apply(), alongside the same tension_snapshot that's itself
## only read once per action -- a hook that rolls its own chance internally
## (unlike get_crit_chance_multiplier's "return a multiplier, let the
## caller roll once" shape) is fine here since stacking multiple such
## traits' probabilities isn't a real design concern this engine has to
## handle. 1.0 = no change.
func get_tension_burn_multiplier(_ctx: BattleContext) -> float:
	return 1.0

## Fires once, from FaintHandler.handle_if_fainted(), right after a real
## faint is confirmed and MonsterFaintedEvent has been emitted -- but
## BEFORE that slot's vacated-slot backfill runs, so a trait that revives
## the owner (Comeback Kid, by directly raising owner.current_hp back above
## 0) pre-empts backfill entirely rather than the monster coming back to a
## slot something else already claimed. Also fires for AoE-on-death
## (Last Gasp) and ally-buff-on-death (Final Breath) traits, which don't
## touch the owner's own fainted state at all.
func on_fainted(_ctx: BattleContext, _owner: MonsterInstance) -> void:
	pass

## Registry mapping a trait id to its concrete TraitEffect subclass. Traits
## need code (behavior), unlike skills/statuses, so this small hardcoded
## switch is the expected seam — a new trait means a new small subclass
## plus one new case here, not a data-only fixture.
##
## skill_db is optional (default null) and only needed by traits that
## inflict a status (e.g. RetaliationStatusTraitEffect) -- BattleContext is
## deliberately thin with no database/registry access (see battle_context.gd),
## so a mid-battle hook has no way to resolve a bare status id string into a
## real StatusData on its own. Resolving it once here, at trait-creation
## time, mirrors exactly how StatusEffect.status_data is already resolved
## once at skill-load time rather than looked up every time a skill fires.
## Every existing call site (TeamToBattleBridge.build_team(),
## tests/fixtures/team_builder.gd) already has a SkillDatabase in hand at
## this exact point, so threading it through cost nothing.
##
## Most real trait names (dodge/crit/counter/turn-order/flee/tension/etc.)
## describe mechanics this battle engine has no subsystem for at all. Rather
## than erroring for every one of those at battle setup, an id with valid
## TraitData but no case below falls through to a plain no-op TraitEffect --
## it's still real, inspectable TraitData (shows up in UI), it just has no
## behavior. Only ids naming an actually-modeled mechanic get a concrete
## subclass.
static func create(id: String, data: TraitData, skill_db: SkillDatabase = null) -> TraitEffect:
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
		# extra_attacks = 1 (attacks twice total) is a placeholder -- no
		# sourced magnitude exists for Hit Squad specifically, so this
		# borrows the closest confirmed number in this same dataset
		# (Double Trouble's explicit "twice"). Double/Triple/Quad Trouble
		# themselves stay unimplemented: their own descriptions gate them on
		# "when not given specific orders," an AI-vs-player-controlled
		# distinction this project has no concept of at all -- every action
		# here is always a specific player order, so there's no "no orders"
		# case for them to ever trigger in.
		"hit_squad":
			effect = ExtraAttackTraitEffect.new()
			effect.extra_attacks = 1
		# hp_roulette/mp_roulette deliberately NOT registered here: unlike
		# attack/defense/agility/wisdom, this engine has no "temporary max
		# HP/MP modifier" concept at all -- MonsterInstance.take_damage()/
		# heal() clamp directly against species.base_hp/base_mp. Bolting a
		# fluctuating max onto that would risk real bugs in core HP tracking
		# for a placeholder-magnitude trait; left as its own follow-up.
		"atk_roulette":
			effect = RandomStatFluctuationTraitEffect.new()
			effect.stat_name = "attack"
		"def_roulette":
			effect = RandomStatFluctuationTraitEffect.new()
			effect.stat_name = "defense"
		"agi_roulette":
			effect = RandomStatFluctuationTraitEffect.new()
			effect.stat_name = "agility"
		"wis_roulette":
			effect = RandomStatFluctuationTraitEffect.new()
			effect.stat_name = "wisdom"
		"star_gift":
			effect = RandomStatFluctuationTraitEffect.new()
			effect.random_stat = true
			effect.fall_chance = 0.0
		"bladed_body":
			# "Damages directly attacked enemy" -- an unconditional retaliation
			# hit, the same shape Gamble Counter already uses (counter_chance
			# 1.0), just for a different narrative reason.
			effect = CounterAttackTraitEffect.new()
			effect.counter_chance = 1.0
			effect.also_negates_damage = false
		"poisonous":
			effect = RetaliationStatusTraitEffect.new()
			effect.status_data = skill_db.get_status("poison") if skill_db != null else null
			effect.chance = 1.0
		"poisonous_poke":
			effect = RetaliationStatusTraitEffect.new()
			effect.status_data = skill_db.get_status("poison") if skill_db != null else null
			effect.chance = 0.3
		"paralysing_punch":
			effect = RetaliationStatusTraitEffect.new()
			effect.status_data = skill_db.get_status("paralysis") if skill_db != null else null
			effect.chance = 0.3
		"paralyzed_attack":
			effect = RetaliationStatusTraitEffect.new()
			effect.status_data = skill_db.get_status("paralysis") if skill_db != null else null
			effect.chance = 1.0
			effect.requires_own_status_id = "paralysis"
		"sleep_sock":
			effect = RetaliationStatusTraitEffect.new()
			effect.status_data = skill_db.get_status("sleep") if skill_db != null else null
			effect.chance = 0.3
		"confusing_touch":
			effect = RetaliationStatusTraitEffect.new()
			effect.status_data = skill_db.get_status("confusion") if skill_db != null else null
			effect.chance = 0.3
		"cursed_attack":
			effect = RetaliationStatusTraitEffect.new()
			effect.status_data = skill_db.get_status("curse") if skill_db != null else null
			effect.chance = 0.3
		"whack_attack":
			effect = RetaliationStatusTraitEffect.new()
			effect.status_data = skill_db.get_status("immobilize") if skill_db != null else null
			effect.chance = 1.0
		"take_magic":
			effect = MpDrainRetaliationTraitEffect.new()
		"close_scraper":
			effect = SurviveLethalHitTraitEffect.new()
		"comeback_kid":
			effect = ReviveTraitEffect.new()
		"final_breath":
			effect = AllyBuffOnFaintTraitEffect.new()
		"last_gasp":
			effect = AoeDamageOnFaintTraitEffect.new()
		"sudden_buff":
			effect = AllyStatBuffOnEntryTraitEffect.new()
			effect.stat_name = "defense"
			effect.stages = 1
			effect.chance = 1.0
		"sudden_oomph":
			effect = AllyStatBuffOnEntryTraitEffect.new()
			effect.stat_name = "attack"
			effect.stages = 2
			effect.chance = 1.0
		"sudden_accelerate":
			effect = AllyStatBuffOnEntryTraitEffect.new()
			effect.stat_name = "agility"
			effect.stages = 1
			effect.chance = 1.0
		"random_accelerate":
			effect = AllyStatBuffOnEntryTraitEffect.new()
			effect.stat_name = "agility"
			effect.stages = 1
			effect.chance = 0.3
		"rabble_rouser":
			effect = AllyTensionBuffOnEntryTraitEffect.new()
		"scare_stare", "intimidating", "coercion", "strangely_alluring":
			effect = EnemyImmobilizeOnEntryTraitEffect.new()
			effect.status_data = skill_db.get_status("immobilize") if skill_db != null else null
			effect.chance = 0.3
		"magic_miser":
			effect = MpCostAndDamageTraitEffect.new()
			effect.mp_cost_multiplier = 0.75
		"magic_scrooge":
			effect = MpCostAndDamageTraitEffect.new()
			effect.mp_cost_multiplier = 0.5
		"spell_splurger":
			effect = MpCostAndDamageTraitEffect.new()
			effect.mp_cost_multiplier = 2.0
		"strong_guard_break":
			effect = MpCostAndDamageTraitEffect.new()
			effect.mp_cost_multiplier = 2.0
			effect.damage_multiplier = 1.5
		"ultra_guard_break":
			effect = MpCostAndDamageTraitEffect.new()
			effect.mp_cost_multiplier = 2.5
			effect.damage_multiplier = 2.0
		"crafty_devil":
			effect = MpCostAndDamageTraitEffect.new()
			effect.mp_cost_multiplier = 1.5
			effect.damage_multiplier = 1.3
		# --- Elemental Ward cluster (ElementalDamageResistanceTraitEffect) ---
		"frizz_ward":
			effect = ElementalDamageResistanceTraitEffect.new()
			effect.elements = ["Frizz"] as Array[String]
		"sizz_ward":
			effect = ElementalDamageResistanceTraitEffect.new()
			effect.elements = ["Sizz"] as Array[String]
		"bang_ward":
			effect = ElementalDamageResistanceTraitEffect.new()
			effect.elements = ["Bang"] as Array[String]
		"zap_ward":
			effect = ElementalDamageResistanceTraitEffect.new()
			effect.elements = ["Zap"] as Array[String]
		"zam_ward":
			effect = ElementalDamageResistanceTraitEffect.new()
			effect.elements = ["Zam"] as Array[String]
		"woosh_ward":
			effect = ElementalDamageResistanceTraitEffect.new()
			effect.elements = ["Woosh"] as Array[String]
		"crack_ward":
			effect = ElementalDamageResistanceTraitEffect.new()
			effect.elements = ["Crack"] as Array[String]
		"dim_ward":
			effect = ElementalDamageResistanceTraitEffect.new()
			effect.elements = ["Dim"] as Array[String]
		"donk_ward":
			effect = ElementalDamageResistanceTraitEffect.new()
			effect.elements = ["Donk"] as Array[String]
		"blunt_ward":
			effect = ElementalDamageResistanceTraitEffect.new()
			effect.elements = ["Blunt"] as Array[String]
		"whack_ward":
			effect = ElementalDamageResistanceTraitEffect.new()
			effect.elements = ["Whack"] as Array[String]
		"abiliterator_ward":
			effect = ElementalDamageResistanceTraitEffect.new()
			effect.elements = ["Abiliterator"] as Array[String]
		"rubblerouser_ward":
			effect = ElementalDamageResistanceTraitEffect.new()
			effect.elements = ["Rubble"] as Array[String]
		"cold_breath_ward":
			effect = ElementalDamageResistanceTraitEffect.new()
			effect.elements = ["Ice"] as Array[String]
		"flame_breath_ward":
			effect = ElementalDamageResistanceTraitEffect.new()
			effect.elements = ["Fire"] as Array[String]
		"all_guard":
			# Universal, not elemental -- reuses the same class metal_body's
			# own family already established, just a smaller flat percentage.
			effect = DamageReductionTraitEffect.new()
			effect.damage_reduction_percent = 0.15
		# --- -meister cluster (damage boost + MP discount, ElementalDamageBoostTraitEffect) ---
		"frizzmeister":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Frizz"] as Array[String]
			effect.damage_multiplier = 1.2
			effect.mp_cost_multiplier = 0.75
		"sizzmeister":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Sizz"] as Array[String]
			effect.damage_multiplier = 1.2
			effect.mp_cost_multiplier = 0.75
		"bangmeister":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Bang"] as Array[String]
			effect.damage_multiplier = 1.2
			effect.mp_cost_multiplier = 0.75
		"crackmeister":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Crack"] as Array[String]
			effect.damage_multiplier = 1.2
			effect.mp_cost_multiplier = 0.75
		"zammeister":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Zam"] as Array[String]
			effect.damage_multiplier = 1.2
			effect.mp_cost_multiplier = 0.75
		"zapmeister":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Zap"] as Array[String]
			effect.damage_multiplier = 1.2
			effect.mp_cost_multiplier = 0.75
		"wooshmeister":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Woosh"] as Array[String]
			effect.damage_multiplier = 1.2
			effect.mp_cost_multiplier = 0.75
		"rubblerouser_meister":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Rubble"] as Array[String]
			effect.damage_multiplier = 1.2
			effect.mp_cost_multiplier = 0.75
		"breath_meister":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Fire", "Ice"] as Array[String]
			effect.damage_multiplier = 1.2
			effect.mp_cost_multiplier = 0.75
		# --- crafty_X elemental cluster (damage boost ONLY -- these never
		# mention an MP change the way -meister traits do) ---
		"crafty_frizzer":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Frizz"] as Array[String]
			effect.damage_multiplier = 1.2
		"crafty_zapper":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Zap"] as Array[String]
			effect.damage_multiplier = 1.2
		"crafty_zammer":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Zam"] as Array[String]
			effect.damage_multiplier = 1.2
		"crafty_sizzer":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Sizz"] as Array[String]
			effect.damage_multiplier = 1.2
		"crafty_woosher":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Woosh"] as Array[String]
			effect.damage_multiplier = 1.2
		"crafty_cracker":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Crack"] as Array[String]
			effect.damage_multiplier = 1.2
		"crafty_donker":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Donk"] as Array[String]
			effect.damage_multiplier = 1.2
		"crafty_rubblerouser":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Rubble"] as Array[String]
			effect.damage_multiplier = 1.2
		"crafty_fire_breather":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Fire"] as Array[String]
			effect.damage_multiplier = 1.2
		"crafty_ice_breather":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Ice"] as Array[String]
			effect.damage_multiplier = 1.2
		"crafty_sealer":
			# Its own description spans both damage elements (Blunt,
			# Abiliterator) AND status-infliction-chance boosts (Fizzle,
			# Gobstopper, Ban Dance) -- only the damage-elemental half is
			# covered here; the status-boost half needs the separate,
			# not-yet-built status-application-chance hook (see the
			# deferred cluster noted below).
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Blunt", "Abiliterator"] as Array[String]
			effect.damage_multiplier = 1.2
		# --- Ban Dance / Drain Magic Ward: confirmed against the real skill
		# data (grep across every fixture's "element" field) that these are
		# plain elemental damage tags with no StatusEffect or StatModEffect
		# attached at all -- unlike the true status-flavored Ward cluster
		# below, they reuse the existing elemental classes directly. ---
		"ban_dance_ward":
			effect = ElementalDamageResistanceTraitEffect.new()
			effect.elements = ["Ban Dance"] as Array[String]
		"drain_magic_ward":
			effect = ElementalDamageResistanceTraitEffect.new()
			effect.elements = ["Drain Magic"] as Array[String]
		"crafty_banger":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Bang"] as Array[String]
			effect.damage_multiplier = 1.2
		"crafty_whacker":
			effect = ElementalDamageBoostTraitEffect.new()
			effect.elements = ["Whack"] as Array[String]
			effect.damage_multiplier = 1.2
		# --- Status-flavored Ward cluster (StatusResistanceTraitEffect) --
		# genuinely distinct from the elemental Ward cluster above: verified
		# against real skill data that e.g. every "Poison"-elemented skill
		# ALSO carries a real StatusEffect(status_id="poison"), so this needs
		# its own hook (get_status_resistance_multiplier, checked from inside
		# StatusEffect.apply()'s own chance roll) rather than reusing the
		# damage-hook classes. ---
		"confusion_ward":
			effect = StatusResistanceTraitEffect.new()
			effect.status_ids = ["confusion"] as Array[String]
		"curse_ward":
			effect = StatusResistanceTraitEffect.new()
			effect.status_ids = ["curse"] as Array[String]
		"dazzle_ward":
			effect = StatusResistanceTraitEffect.new()
			effect.status_ids = ["dazzle"] as Array[String]
		"gobstopper_ward":
			effect = StatusResistanceTraitEffect.new()
			effect.status_ids = ["gobstop"] as Array[String]
		"paralysis_ward":
			effect = StatusResistanceTraitEffect.new()
			effect.status_ids = ["paralysis"] as Array[String]
		"poison_ward":
			effect = StatusResistanceTraitEffect.new()
			effect.status_ids = ["poison"] as Array[String]
		"sleep_ward":
			effect = StatusResistanceTraitEffect.new()
			effect.status_ids = ["sleep"] as Array[String]
		"inaction_ward":
			# "Increases Snooze Resistance" -- immobilize is this engine's
			# closest modeled equivalent to a stun/miss-a-turn status.
			effect = StatusResistanceTraitEffect.new()
			effect.status_ids = ["immobilize"] as Array[String]
		"fizzle_ward":
			# "Fizzle" = prevented from casting magic = silence.
			effect = StatusResistanceTraitEffect.new()
			effect.status_ids = ["silence"] as Array[String]
		# --- Status-flavored crafty_X cluster (StatusInflictionBoostTraitEffect) ---
		"crafty_confuser":
			effect = StatusInflictionBoostTraitEffect.new()
			effect.status_ids = ["confusion"] as Array[String]
		"crafty_curser":
			effect = StatusInflictionBoostTraitEffect.new()
			effect.status_ids = ["curse"] as Array[String]
		"crafty_paralyzer":
			effect = StatusInflictionBoostTraitEffect.new()
			effect.status_ids = ["paralysis"] as Array[String]
		"crafty_poisoner":
			effect = StatusInflictionBoostTraitEffect.new()
			effect.status_ids = ["poison"] as Array[String]
		"crafty_sleeper":
			effect = StatusInflictionBoostTraitEffect.new()
			effect.status_ids = ["sleep"] as Array[String]
		"crafty_inactivist":
			effect = StatusInflictionBoostTraitEffect.new()
			effect.status_ids = ["immobilize"] as Array[String]
		"crafty_jammer":
			# Partial coverage -- see the class doc comment: only Dazzle of
			# "Dazzle, Drain Magic, Magic Frailty" maps to a real status.
			effect = StatusInflictionBoostTraitEffect.new()
			effect.status_ids = ["dazzle"] as Array[String]
		"metal_killer":
			# Same class Hunter Mech already uses, reused with its own flat
			# bonus -- no sourced magnitude exists for this trait
			# specifically, a documented placeholder distinct from Hunter
			# Mech's own real "+1 point" number.
			effect = BonusDamageVsMetalBodyTraitEffect.new()
			effect.flat_bonus = 3
		"fly_swatter":
			# Already fully functional as-is: ChanceBasedDamageNegationTraitEffect's
			# blocked_by_trait_id check reads the ATTACKER's trait_data.id
			# directly, which is set below regardless of which effect class
			# (or none) fly_swatter itself resolves to. This case exists
			# purely to document that intentionally, not to add new behavior.
			effect = TraitEffect.new()
		"drain_magic_attack":
			effect = MpDrainOnAttackTraitEffect.new()
		"attalleric":
			effect = DamageTakenMultiplierTraitEffect.new()
		"able_ambusher":
			# "Guaranteed pre-emptive attack" -- this engine has no separate
			# surprise/ambush round, only intra-round action-order priority,
			# so this is honestly approximated as a priority bonus large
			# enough to dominate every other priority trait (even Ultra Fast
			# Action's 200).
			effect = PriorityBonusTraitEffect.new()
			effect.priority_bonus = 300
		"stress_relief":
			effect = TensionStealOnAttackedTraitEffect.new()
		"mutter":
			effect = EnemyTensionDrainOnTurnTraitEffect.new()
		"heckling_hector":
			# "Automatically decreases all enemy tension when one enemy
			# increases tension" -- a documented approximation of a trigger
			# this engine can't literally observe (see the class doc
			# comment): reacts to the CURRENT state (any enemy already
			# having tension) each of the owner's turns, rather than the
			# exact moment an increase happens. "Automatically" means no
			# chance roll and a full drain, unlike Mutter's own chance-based
			# partial one.
			effect = EnemyTensionDrainOnTurnTraitEffect.new()
			effect.require_any_enemy_tension = true
			effect.levels = 4
		"stalwart_spirit":
			effect = TensionGainOnStatusTraitEffect.new()
		"dust_of_the_clan":
			effect = TensionBurnMultiplierTraitEffect.new()
		"rival_riler":
			effect = EnemyTensionBuffOnEntryTraitEffect.new()
		"hidden_power":
			effect = StackingStatBuffOnTurnTraitEffect.new()
		"rocket_start":
			effect = RoundGatedDamageMultiplierTraitEffect.new()
		# --- StatModEffect resistance/infliction cluster: confirmed against
		# real skill data (sag.json/sap.json/decelerate.json) that these are
		# pure StatModEffect stat debuffs with no chance roll at all before
		# this entry -- a materially different gap from the status-chance
		# cluster above, needing its own StatModEffect.element-keyed hook
		# pair. ---
		"sag_ward":
			effect = StatModResistanceTraitEffect.new()
			effect.elements = ["Sag"] as Array[String]
		"sap_ward":
			effect = StatModResistanceTraitEffect.new()
			effect.elements = ["Sap"] as Array[String]
		"decelerate_ward":
			effect = StatModResistanceTraitEffect.new()
			effect.elements = ["Decelerate"] as Array[String]
		"crafty_debuffer":
			# Partial coverage, same precedent as Crafty Sealer/Crafty Jammer:
			# "Dim" turned out (checking dim.json) to be a plain elemental
			# damage move with no StatModEffect attached, unlike Sag/Sap/
			# Decelerate, so only those three are covered here.
			effect = StatModInflictionBoostTraitEffect.new()
			effect.elements = ["Sag", "Sap", "Decelerate"] as Array[String]
		"health_professional":
			effect = HealBoostAndMpDiscountTraitEffect.new()
		"timid", "yellow_belly", "foot_dragger":
			effect = SelfSkipTurnTraitEffect.new()
		"medicinal_knowledge":
			effect = CureAllyStatusOnTurnTraitEffect.new()
		"proactive_hunter":
			effect = ProactiveHunterTraitEffect.new()
		"suicidal_satisfaction":
			# "Chance of spells hitting a weak point rises when near death" --
			# reuses the same HP-gated crit-chance-multiplier shape Desperado
			# already established (real DQM terminology treats "weak point" as
			# synonymous with a critical hit), with its own placeholder
			# threshold/multiplier.
			effect = DesperadoTraitEffect.new()
			effect.hp_threshold_percent = 0.25
			effect.multiplier_when_low = 1.5
		"tit_for_tat":
			effect = TitForTatTraitEffect.new()
		"giant_killer":
			effect = BonusDamageVsSizeTraitEffect.new()
			effect.target_slots = 4
		"standard_killer":
			# "Deal a heavy blow to smaller monsters" -- interpreted
			# literally as the Small size tier (slots == 1), by symmetry
			# with Giant Killer's own tier-4 targeting rather than the
			# trait's own id (which would suggest tier 2).
			effect = BonusDamageVsSizeTraitEffect.new()
			effect.target_slots = 1
		"big_hitter":
			# "Has less HP, but Attack and Skill damage is increased" --
			# the HP reduction is already baked into this monster's
			# imported base_hp fixture value (the spreadsheet's own HP
			# column already reflects it), so the only actionable part is
			# the damage boost. Reuses MpCostAndDamageTraitEffect purely
			# for its already-unconditional damage_multiplier -- its own
			# mp_cost_multiplier stays at its 1.0 default, since this trait
			# has nothing to do with MP.
			effect = MpCostAndDamageTraitEffect.new()
			effect.damage_multiplier = 1.2
		"paralyzing":
			# "Inflicts paralysis on enemies directly attacked" -- a
			# guaranteed (no "may"/"chance" wording) version of the same
			# retaliation shape Paralysing Punch already uses at chance=0.3.
			# A real oversight from the original Retaliation family pass,
			# caught on a later re-audit.
			effect = RetaliationStatusTraitEffect.new()
			effect.status_data = skill_db.get_status("paralysis") if skill_db != null else null
			effect.chance = 1.0
		"sobering_slap":
			# "Defuddles or Awakens allies in battle" -- cures confusion
			# ("defuddles") and sleep ("awakens"), the exact same shape
			# Medicinal Knowledge already established for poison.
			effect = CureAllyStatusOnTurnTraitEffect.new()
			effect.status_ids = ["confusion", "sleep"] as Array[String]
		"tension_relief_body":
			# "Absorbs Tension of directly attacked enemy and increases own
			# Tension" -- word-for-word the same trait Stress Relief already
			# implements; another real oversight from that earlier pass.
			effect = TensionStealOnAttackedTraitEffect.new()
		"violent_rager":
			effect = HpForTensionTraitEffect.new()
		# --- Skill-Type combat-archetype cluster (SkillTypeDamageBoostTraitEffect) ---
		"great_sage":
			effect = SkillTypeDamageBoostTraitEffect.new()
			effect.skill_types = ["Spell"] as Array[String]
		"warrior":
			# "Breaker skills more effective" -- the only imported move with
			# "Breaker" in its name (Heart Breaker) is Type=Slash, and
			# Slash fits a sword-wielding "Warrior" archetype thematically;
			# a documented interpretation, not a certain one.
			effect = SkillTypeDamageBoostTraitEffect.new()
			effect.skill_types = ["Slash"] as Array[String]
		"combat_king":
			# "Increases the effectiveness of ART property abilities" --
			# "ART" isn't a literal Type value in the imported vocabulary;
			# interpreted as Body (hand-to-hand/martial-arts skills),
			# distinct from Warrior's own Slash-weapon focus. A documented
			# interpretation, not a certain one.
			effect = SkillTypeDamageBoostTraitEffect.new()
			effect.skill_types = ["Body"] as Array[String]
		"deadly_breath":
			# "BRE property" maps directly and unambiguously to Breath.
			effect = SkillTypeDamageBoostTraitEffect.new()
			effect.skill_types = ["Breath"] as Array[String]
		"dance_meister":
			effect = SkillTypeDamageBoostTraitEffect.new()
			effect.skill_types = ["Dance"] as Array[String]
			effect.mp_cost_multiplier = 0.75
		"divine_dancer":
			# Only ever mentions the damage boost, never MP -- same
			# damage-only-vs-damage-plus-MP-discount split the elemental
			# crafty_X/-meister pair already established.
			effect = SkillTypeDamageBoostTraitEffect.new()
			effect.skill_types = ["Dance"] as Array[String]
		# --- Autonomous self-cast cluster: real skills that exist as
		# SkillData, but whose OWN effect data had to be corrected first
		# (buff.json/ping.json/kaping.json/oomphle.json were wrongly
		# modeled as dealing self-damage -- see wiki/log.md) before a trait
		# could meaningfully "cast" them at all. ---
		"random_buff":
			effect = SelfCastSkillOnTurnTraitEffect.new()
			effect.skill_data = skill_db.get_skill("buff") if skill_db != null else null
		"random_oomph":
			effect = SelfCastSkillOnTurnTraitEffect.new()
			effect.skill_data = skill_db.get_skill("oomph") if skill_db != null else null
		"random_ping":
			effect = SelfCastSkillOnTurnTraitEffect.new()
			effect.skill_data = skill_db.get_skill("ping") if skill_db != null else null
		"sudden_ping":
			effect = SelfCastSkillOnEntryTraitEffect.new()
			effect.skill_data = skill_db.get_skill("ping") if skill_db != null else null
		"random_shuffle":
			effect = SelfCastSkillOnTurnTraitEffect.new()
			effect.skill_data = skill_db.get_skill("shuffle") if skill_db != null else null
		"sudden_shuffle":
			effect = SelfCastSkillOnEntryTraitEffect.new()
			effect.skill_data = skill_db.get_skill("shuffle") if skill_db != null else null
		"random_reversal":
			effect = SelfCastSkillOnTurnTraitEffect.new()
			effect.skill_data = skill_db.get_skill("unnatural_order") if skill_db != null else null
		"sudden_reverse":
			effect = SelfCastSkillOnEntryTraitEffect.new()
			effect.skill_data = skill_db.get_skill("unnatural_order") if skill_db != null else null
		"wave_of_relief":
			effect = SelfCastSkillOnTurnTraitEffect.new()
			effect.skill_data = skill_db.get_skill("wave_of_relief") if skill_db != null else null
		"wave_of_panic":
			effect = SelfCastSkillOnTurnTraitEffect.new()
			effect.skill_data = skill_db.get_skill("wave_of_panic") if skill_db != null else null
			effect.target_random_enemy = true
		"grand_slammer":
			# "Increases overall attack for gigantic monsters depending on
			# the skill" -- "depending on the skill" gives no formula or
			# per-skill table to work from, so this simplifies to the same
			# flat unconditional boost Big Hitter uses, just a slightly
			# larger placeholder multiplier for "gigantic" vs "large."
			effect = MpCostAndDamageTraitEffect.new()
			effect.damage_multiplier = 1.3
		# Also deliberately unregistered, all with a concrete reason:
		# - magical_sabotage_ward: names "Magic Frailty" and "Spooky Aura,"
		#   neither of which matches any imported skill or mechanic.
		# - crafty_squasher: names a move ("Squash") that doesn't clearly
		#   match anything in the imported Attribute vocabulary.
		# - escape_artist ("Flee is guaranteed to succeed"): the Flee command
		#   was removed from this engine entirely earlier this session, per
		#   explicit user request -- there is no flee mechanic left for this
		#   trait to guarantee.
		# - deadly_touch ("may stifle enemy attacks"): "stifle" is genuinely
		#   ambiguous between Silence and just blocking the current hit --
		#   skipped rather than guessing, same precedent as every other
		#   textually-ungrounded trait below.
		# - berserker ("attacks with Hatchet Man when panicking") and
		#   rolled_over ("attacks all enemies upon falling asleep") both need
		#   the engine to auto-select and cast a specific move outside the
		#   player's own turn order -- no AI-triggered auto-action system
		#   exists at all (every action in this engine is a specific player
		#   order).
		# - bouncer ("permanently applies Bounce, undispellable"): Bounce
		#   (reflecting spells back at their caster) isn't one of the 9 real
		#   statuses this engine models, and no damage-redirect/reflect hook
		#   exists to build a non-status version of it either.
		# - protecter ("occasionally protects allies, takes all damage") and
		#   small_body (same "pulls the attack to itself" redirect) both need
		#   re-routing a hit's TARGET mid-resolution, before damage is ever
		#   computed for the original target -- a materially different,
		#   invasive hook shape from anything else in this file (the same
		#   "ally-targeting redirect" gap noted as out of scope since the
		#   original trait audit).
		# - counteractivist: circular description ("applies Counteractivist"
		#   -- referencing itself) with no textual grounding for what it
		#   actually does.
		# - talent-scout cluster (genius_talent_scout, pro_talent_scout,
		#   talent_scout), lootist, gold_getter, fast_learner, lucky,
		#   unlucky, protection_of_the_stars: all need a
		#   scouting/EXP/gold/item-drop/Luck-stat system that
		#   doesn't exist in this project, unchanged since the original
		#   trait audit's scope decision.
		# - master_of_weapons ("Allows monster to equip every type of
		#   weapon") is no longer in this excluded list -- now that a real
		#   weapon-equip system exists (see wiki/log.md), it's implemented,
		#   but not through this factory: equip-eligibility is a
		#   team-builder-time rule, not a battle-runtime hook, so
		#   MonsterEquipmentRules.get_equippable_weapon_types() special-cases
		#   the trait id directly (same "read a trait id without a
		#   TraitEffect instance" pattern BonusDamageVsMetalBodyTraitEffect
		#   already uses) instead of getting a TraitEffect.create() entry.
		# - sore_loser ("bonus vs a higher-level enemy"): needs a monster
		#   "level" concept this engine has never had (confirmed: no `level`
		#   field exists anywhere on MonsterInstance or MonsterSpecies) --
		#   proactive_hunter, its sibling trait in the original audit note,
		#   got peeled off this entry since its own "acted this turn" flag
		#   was buildable without new sourced data.
		# - double_trouble/triple_trouble/quad_trouble and the
		#   tactical_genius/tactical_mastermind/tactical_trooper/tactical_uber
		#   cluster: same "acts extra times when not given specific orders"
		#   AI-vs-player-order distinction already noted at hit_squad above
		#   -- this engine has no concept of an order-less turn.
		# The autonomous-self-cast mechanism (SelfCastSkillOnTurnTraitEffect/
		# SelfCastSkillOnEntryTraitEffect) unlocked random_buff/random_oomph/
		# random_ping/sudden_ping once Buff/Ping/Kaping/Oomphle's own broken
		# effect data got fixed, then random_shuffle/sudden_shuffle/
		# random_reversal/sudden_reverse/wave_of_relief/wave_of_panic once
		# Shuffle/Unnatural Order got a real new turn-order-override
		# SkillEffect (TurnOrderOverrideEffect, consumed by
		# TurnManager.run_turn() the NEXT round -- see BattleState.
		# shuffle_next_round's own doc comment for why not retroactively)
		# and the whole cure-status/restore-mp family (CureStatusEffect/
		# RestoreMpEffect) got built out. Wave of Panic needed
		# SelfCastSkillOnTurnTraitEffect's own target_random_enemy option
		# added, since (unlike every other self-cast registration) it's the
		# one single-enemy-targeted skill in this cluster. Heckling Hector,
		# Stalwart Spirit, and Dust of the Clan (all tension-family, all
		# initially assumed blocked on a missing hook/data) turned out
		# buildable on a closer re-read: Heckling Hector approximates its
		# "reacts when an enemy's tension rises" trigger by checking
		# whether any enemy currently HAS tension each of the owner's own
		# turns (EnemyTensionDrainOnTurnTraitEffect's new
		# require_any_enemy_tension flag); Stalwart Spirit ("stasis"
		# interpreted as immobilize, the same analogy Inaction Ward/Crafty
		# Inactivist already use) just needed Tit for Tat's own
		# on_status_afflicted hook reused, not a new one; Dust of the
		# Clan's "same family allies" clause collapses to self-only (the
		# same simplification every ally-scoped effect here already uses),
		# leaving a clean single-monster "chance of 2x Tension Burn" (new
		# get_tension_burn_multiplier hook, computed once per action
		# alongside the existing tension_snapshot).
		#
		# Genuinely still blocked, not just on the autonomous-cast mechanism
		# (which now works fine) but because the underlying skill itself
		# still needs a subsystem this engine doesn't have at all: Sudden/
		# Random Black/Red/White/Underworld Fog (global field effects
		# spanning both sides of the battle, not per-monster state), Rare
		# Magic Barrier (reduces foes' spell effectiveness -- a side-wide
		# damage-reduction field), Rare Mist Me (a one-time "negate the next
		# hit" self-buff). Disruptive Wave DOES exist as a real skill
		# ("removes almost all magical effects from all enemies") --
		# correcting an earlier, wrong claim in this same comment block --
		# but needs a dispel-enemy-buffs SkillEffect and AOE-enemy
		# targeting, neither of which exists; its own target_type is even
		# internally inconsistent with its description (single_enemy vs.
		# "all enemies"), a data problem on top of the missing mechanic.
		# **The same broken-self-damage-effect pattern this whole
		# cluster started from also turned up on a broader sweep across 60+
		# OTHER skill fixtures unrelated to any missing trait** (Kaclang,
		# Bounce, the whole Counter/reflect-stance family, the revive spells
		# Zing/Kazing/Prezing/Song of Salvation, the MP-transfer spells Give
		# Magic/Share Magic, and more) -- real gameplay bugs (these are all
		# player-usable moves today), but fixing them needs ally/AOE
		# targeting and a reflect-stance subsystem this engine doesn't have,
		# a separate, larger follow-up flagged for the user rather than
		# attempted here. Candy Carnival is
		# explicitly conditional on OTHER monsters' traits in the same
		# party, its own description
		# gives no further detail on what that means. Of the monster-Size
		# cluster, giant_killer/standard_killer/big_hitter/grand_slammer got
		# peeled off and registered above once MonsterSpecies.slots turned
		# out to already BE the size tier -- the rest of that cluster stays
		# out for reasons that turned out to be unrelated to missing size
		# data at all: small_body and standard_body are actually the
		# ally-damage-redirect traits ("pulls the attack to itself to
		# protect smaller allies"), the same architecturally-invasive gap
		# protecter is excluded for above, regardless of size data being
		# available now. ultra_body ("echo effect... striking all enemies
		# at once. Their damage cap is always 9999") needs two mechanics
		# that don't exist independent of size: a target-selection override
		# (hitting every enemy regardless of the cast skill's own declared
		# target_type) and a damage-cap concept this engine has never had at
		# all (there's no existing default cap to even compare "9999"
		# against). dead_obsession
		# ("acts until the end of the round even after dying") and
		# grudge_bearer ("occasionally reverses effect when defeated" --
		# reverses WHAT effect is never specified) also stay unregistered:
		# Dead Obsession would mean suppressing is_fainted() checks across a
		# wide, easy-to-miss surface (TurnManager's action loop,
		# EndOfTurnProcessor, every trait hook that already assumes a dead
		# monster can't act) for a single monster for the rest of one
		# specific round -- real architectural surgery, not a new hook, and
		# risky to bolt on for one trait. Grudge Bearer's own description
		# gives no textual grounding for what "reverses" even means. All
		# deliberately skipped rather than inventing mechanics with no
		# grounding.
		_:
			effect = TraitEffect.new()
	effect.trait_data = data
	return effect
