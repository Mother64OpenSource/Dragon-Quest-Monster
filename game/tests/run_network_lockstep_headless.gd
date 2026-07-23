extends SceneTree

## CLI/CI entry point:
##   godot --headless --path game --script res://tests/run_network_lockstep_headless.gd
func _initialize() -> void:
	var runner := NetworkLockstepTestRunner.new()
	var ok: bool = runner.run()
	quit(0 if ok else 1)
