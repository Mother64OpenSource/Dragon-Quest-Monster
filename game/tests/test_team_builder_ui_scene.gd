extends Node

## Editor/manual-verification entry point: open test_team_builder_ui_scene.tscn
## and press F6.
func _ready() -> void:
	var runner := TeamBuilderUiTestRunner.new()
	var ok: bool = await runner.run(get_tree())
	get_tree().quit(0 if ok else 1)
