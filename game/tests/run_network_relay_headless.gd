extends SceneTree

## CLI/CI entry point:
##   godot --headless --path game --script res://tests/run_network_relay_headless.gd
func _initialize() -> void:
	var runner := NetworkRelayTestRunner.new()
	var ok: bool = await runner.run(self)
	quit(0 if ok else 1)
