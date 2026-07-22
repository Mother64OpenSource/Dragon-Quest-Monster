class_name StatModEffect
extends SkillEffect

@export var stat_name: String = "attack"
@export var stages: int = 1
@export var chance: float = 1.0
@export var target_self: bool = true

func apply(ctx: BattleContext, user: MonsterInstance, target: MonsterInstance) -> void:
	var recipient := user if target_self else target
	if recipient.is_fainted():
		return
	if not ctx.rng.chance(chance):
		return
	var applied_delta := recipient.apply_stat_stage(stat_name, stages)
	var new_stage := recipient.stat_stages.get_stage(stat_name)
	ctx.event_bus.emit_event(
		StatChangedEvent.new(recipient.instance_id, stat_name, applied_delta, new_stage),
		ctx.state.turn_number
	)
