class_name SelfCastSkillOnTurnTraitEffect
extends TraitEffect

## Generic "chance to autonomously cast a specific skill on itself during
## battle" trait (Random Buff/Oomph/Ping). skill_data is resolved once at
## TraitEffect.create() time via the optional skill_db param -- mirrors
## RetaliationStatusTraitEffect's own status_data resolution, since a
## mid-battle hook has no database reference of its own to look a skill up
## with. Rolled once per owner turn start (same StartOfTurnProcessor timing
## as the rest of the per-turn trait family), then routed through the real
## ActionExecutor.execute() pipeline -- its own accuracy roll, MP cost
## (fizzles exactly like a player-chosen cast would if unaffordable), the
## works -- not a shortcut that silently applies the effect for free.
##
## Deliberately scoped to self-targeted buffs (or the single-enemy-target
## Wave of Panic, via target_random_enemy) rather than anything that could
## faint someone through a multi-hit/crit path: doesn't re-check
## VictoryChecker after casting. A future registration that autonomously
## casts real damage would need that reconsidered.

@export var skill_data: SkillData
@export var chance: float = 0.15
## True for Random Wave of Panic -- casts at a random active enemy instead
## of the owner itself, mirroring EnemyImmobilizeOnEntryTraitEffect's own
## "side_b if side_a else side_a" enemy-side pattern.
@export var target_random_enemy: bool = false

func on_turn_start(ctx: BattleContext, owner: MonsterInstance) -> void:
	if skill_data == null or owner.is_fainted() or not ctx.rng.chance(chance):
		return
	var target_instance_id := owner.instance_id
	if target_random_enemy:
		var enemy_side := "side_b" if owner.side == "side_a" else "side_a"
		var enemies := ctx.state.get_active_monsters(enemy_side)
		if enemies.is_empty():
			return
		target_instance_id = enemies[ctx.rng.randi_range(0, enemies.size() - 1)].instance_id
	var skill_lookup := {skill_data.id: skill_data}
	ActionExecutor.execute(ctx, Action.new(owner.instance_id, skill_data.id, target_instance_id), skill_lookup)
