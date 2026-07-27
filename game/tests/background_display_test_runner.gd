class_name BackgroundDisplayTestRunner
extends RefCounted

## Instances the real BackgroundDisplay scene and drives it directly (no
## simulated timers -- _on_frame_timer_timeout() is called by hand, same
## "call handler methods directly" convention used throughout the UI test
## suites, since waiting on a real Timer would make this test's runtime
## depend on GIF frame delays).

const TEST_PNG_PATH := "user://test_background_display.png"
const TEST_GIF_PATH := "user://test_background_display.gif"
const Scene := preload("res://ui/background/background_display.tscn")

var _all_passed := true

func run(tree: SceneTree) -> bool:  # coroutine (awaits a frame internally)
	_all_passed = true
	_clear_test_files()

	var display: BackgroundDisplay = Scene.instantiate()
	tree.root.add_child(display)
	# @onready children aren't resolved until the engine processes a frame,
	# same as every other headless UI test in this suite.
	await tree.process_frame

	_check("starts with a fallback gradient texture (no path set yet)", display._texture_rect.texture is GradientTexture2D)

	_write_test_png()
	display.set_background_path(TEST_PNG_PATH)
	_check("loading a static PNG sets an ImageTexture", display._texture_rect.texture is ImageTexture)
	_check(
		"loaded PNG texture has the expected dimensions",
		display._texture_rect.texture.get_width() == 4 and display._texture_rect.texture.get_height() == 4
	)

	_write_test_gif()
	display.set_background_path(TEST_GIF_PATH)
	_check("loading a GIF decodes both encoded frames", display._gif_frames.size() == 2)
	_check("GIF display starts on frame 0", display._gif_frame_index == 0)
	var first_texture := display._texture_rect.texture

	display._on_frame_timer_timeout()
	_check("frame timer firing advances to frame 1", display._gif_frame_index == 1)
	_check("advancing a frame actually swaps the displayed texture", display._texture_rect.texture != first_texture)

	display._on_frame_timer_timeout()
	_check("frame index wraps back to 0 after the last frame", display._gif_frame_index == 0)

	display.set_background_path("user://does_not_exist.png")
	_check("a missing file falls back to the gradient", display._texture_rect.texture is GradientTexture2D)

	display.set_background_path("user://unsupported_background.txt")
	_check("an unsupported extension falls back to the gradient", display._texture_rect.texture is GradientTexture2D)

	display.set_background_path(TEST_PNG_PATH)
	display.set_background_path("")
	_check("an empty path falls back to the gradient", display._texture_rect.texture is GradientTexture2D)

	display.queue_free()
	_clear_test_files()

	if _all_passed:
		print("BackgroundDisplayTestRunner: ALL CHECKS PASSED")
	else:
		print("BackgroundDisplayTestRunner: SOME CHECKS FAILED")
	return _all_passed

func _write_test_png() -> void:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 0, 0, 1))
	image.save_png(TEST_PNG_PATH)

func _write_test_gif() -> void:
	var palette := PackedColorArray([
		Color(1, 0, 0, 1), Color(0, 1, 0, 1), Color(0, 0, 1, 1), Color(1, 1, 0, 1)
	])
	var frame_a := PackedByteArray([0, 0, 0, 0])
	var frame_b := PackedByteArray([2, 2, 2, 2])
	var bytes := GifTestFixtureBuilder.build(2, 2, palette, [
		{"pixels": frame_a, "delay_hundredths": 5},
		{"pixels": frame_b, "delay_hundredths": 5},
	])
	var file := FileAccess.open(TEST_GIF_PATH, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()

func _clear_test_files() -> void:
	if FileAccess.file_exists(TEST_PNG_PATH):
		DirAccess.remove_absolute(TEST_PNG_PATH)
	if FileAccess.file_exists(TEST_GIF_PATH):
		DirAccess.remove_absolute(TEST_GIF_PATH)

func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		print("FAIL: %s" % label)
		_all_passed = false
