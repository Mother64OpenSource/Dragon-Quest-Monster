extends SceneTree

## CLI/CI entry point:
##   godot --headless --path game --script res://tests/run_gif_decoder_headless.gd
func _initialize() -> void:
	var runner := GifDecoderTestRunner.new()
	var ok := runner.run()
	quit(0 if ok else 1)
