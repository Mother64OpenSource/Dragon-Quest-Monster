extends Node

## Editor/manual-verification entry point: open test_scene.tscn and press F6,
## or run `godot --headless --path game res://tests/test_scene.tscn`.
func _ready() -> void:
	var runner := BattleTestRunner.new()
	var ok := runner.run()
	get_tree().quit(0 if ok else 1)
