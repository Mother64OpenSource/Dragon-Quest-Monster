class_name ScriptedTurns
extends RefCounted

## Builds the two ScriptedActionProviders for the M1 headless test battle:
## Side A (Slime, backfilling to Dracky once Slime faints) vs Side B (Golem
## alone). Every number produced by this exact script is hand-computable —
## see BattleTestRunner for the expected-value assertions it drives.
static func build_providers(slime: MonsterInstance, dracky: MonsterInstance, golem: MonsterInstance) -> Dictionary:
	var side_a_provider := ScriptedActionProvider.new()

	var slime_queue: Array[Action] = [
		Action.new(slime.instance_id, "oomph", slime.instance_id),
		Action.new(slime.instance_id, "attack", golem.instance_id),
	]
	side_a_provider.set_queue(slime.instance_id, slime_queue)

	var dracky_queue: Array[Action] = [
		Action.new(dracky.instance_id, "poison_breath", golem.instance_id),
		Action.new(dracky.instance_id, "attack", golem.instance_id),
	]
	side_a_provider.set_queue(dracky.instance_id, dracky_queue)

	var side_b_provider := ScriptedActionProvider.new()
	var golem_queue: Array[Action] = [
		Action.new(golem.instance_id, "attack", slime.instance_id),
		Action.new(golem.instance_id, "double_slash", slime.instance_id),
		Action.new(golem.instance_id, "attack", dracky.instance_id),
		Action.new(golem.instance_id, "attack", dracky.instance_id),
	]
	side_b_provider.set_queue(golem.instance_id, golem_queue)

	return {
		"side_a": side_a_provider,
		"side_b": side_b_provider,
	}
