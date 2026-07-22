extends SceneTree

## CLI/CI entry point:
##   godot --headless --path game --script res://tests/run_battle_headless.gd
## Must extend SceneTree for Godot's --script flag to take over the main
## loop rather than silently no-op.
func _initialize() -> void:
	var runner := BattleTestRunner.new()
	var ok := runner.run()
	quit(0 if ok else 1)
