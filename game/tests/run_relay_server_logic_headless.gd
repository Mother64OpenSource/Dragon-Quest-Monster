extends SceneTree

## CLI/CI entry point:
##   godot --headless --path game --script res://tests/run_relay_server_logic_headless.gd
func _initialize() -> void:
	var runner := RelayServerLogicTestRunner.new()
	var ok: bool = runner.run()
	quit(0 if ok else 1)
