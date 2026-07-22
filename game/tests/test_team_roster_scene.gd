extends Node

## Editor/manual-verification entry point: open test_team_roster_scene.tscn
## and press F6.
func _ready() -> void:
	var runner := TeamRosterTestRunner.new()
	var ok := runner.run()
	get_tree().quit(0 if ok else 1)
