extends SceneTree

## CLI/CI entry point:
##   godot --headless --path game --script res://tests/run_team_roster_headless.gd
func _initialize() -> void:
	var runner := TeamRosterTestRunner.new()
	var ok := runner.run()
	quit(0 if ok else 1)
