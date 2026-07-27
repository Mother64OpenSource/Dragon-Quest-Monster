class_name GifDecoderTestRunner
extends RefCounted

## GifDecoder checks, using GifTestFixtureBuilder to hand-build small valid
## GIF byte streams (no ready-made test GIF file exists in this project).

var _all_passed := true

func run() -> bool:
	_all_passed = true

	_check_single_frame()
	_check_multi_frame_and_delays()
	_check_malformed_input()

	if _all_passed:
		print("GifDecoderTestRunner: ALL CHECKS PASSED")
	else:
		print("GifDecoderTestRunner: SOME CHECKS FAILED")
	return _all_passed

func _check_single_frame() -> void:
	var palette := PackedColorArray([
		Color(1, 0, 0, 1), Color(0, 1, 0, 1), Color(0, 0, 1, 1), Color(1, 1, 0, 1)
	])
	var pixels := PackedByteArray([0, 1, 2, 3])  # 2x2: red, green, blue, yellow
	var bytes := GifTestFixtureBuilder.build(2, 2, palette, [
		{"pixels": pixels, "delay_hundredths": 10},
	])

	var frames: Array = GifDecoder.decode(bytes)
	_check("single-frame GIF decodes to exactly 1 frame", frames.size() == 1)
	if frames.is_empty():
		return

	var frame: GifFrame = frames[0]
	_check("decoded frame has the right dimensions", frame.texture.get_width() == 2 and frame.texture.get_height() == 2)
	_check("decoded frame's delay matches the encoded 10 hundredths (0.1s)", is_equal_approx(frame.delay_sec, 0.1))

	var image := frame.texture.get_image()
	_check("pixel (0,0) decodes to red", image.get_pixel(0, 0).is_equal_approx(Color(1, 0, 0, 1)))
	_check("pixel (1,0) decodes to green", image.get_pixel(1, 0).is_equal_approx(Color(0, 1, 0, 1)))
	_check("pixel (0,1) decodes to blue", image.get_pixel(0, 1).is_equal_approx(Color(0, 0, 1, 1)))
	_check("pixel (1,1) decodes to yellow", image.get_pixel(1, 1).is_equal_approx(Color(1, 1, 0, 1)))

func _check_multi_frame_and_delays() -> void:
	var palette := PackedColorArray([
		Color(1, 0, 0, 1), Color(0, 1, 0, 1), Color(0, 0, 1, 1), Color(1, 1, 0, 1)
	])
	var frame_a := PackedByteArray([0, 0, 0, 0])  # all red
	var frame_b := PackedByteArray([2, 2, 2, 2])  # all blue
	var bytes := GifTestFixtureBuilder.build(2, 2, palette, [
		{"pixels": frame_a, "delay_hundredths": 5},
		{"pixels": frame_b, "delay_hundredths": 20},
	])

	var frames: Array = GifDecoder.decode(bytes)
	_check("two-frame GIF decodes to exactly 2 frames", frames.size() == 2)
	if frames.size() != 2:
		return

	var first: GifFrame = frames[0]
	var second: GifFrame = frames[1]
	_check("frame 1's delay matches its own encoded value (0.05s)", is_equal_approx(first.delay_sec, 0.05))
	_check("frame 2's delay matches its own DIFFERENT encoded value (0.2s), not frame 1's", is_equal_approx(second.delay_sec, 0.2))

	var image_a := first.texture.get_image()
	var image_b := second.texture.get_image()
	_check("frame 1 is all red as encoded", image_a.get_pixel(0, 0).is_equal_approx(Color(1, 0, 0, 1)) and image_a.get_pixel(1, 1).is_equal_approx(Color(1, 0, 0, 1)))
	_check("frame 2 is all blue as encoded, not a leftover copy of frame 1", image_b.get_pixel(0, 0).is_equal_approx(Color(0, 0, 1, 1)) and image_b.get_pixel(1, 1).is_equal_approx(Color(0, 0, 1, 1)))

func _check_malformed_input() -> void:
	var not_a_gif := "this is definitely not a gif file".to_utf8_buffer()
	var frames: Array = GifDecoder.decode(not_a_gif)
	_check("a non-GIF byte stream decodes to an empty array without crashing", frames.is_empty())

	var empty: PackedByteArray = PackedByteArray()
	var frames2: Array = GifDecoder.decode(empty)
	_check("an empty byte stream decodes to an empty array without crashing", frames2.is_empty())

func _check(label: String, condition: bool) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		print("FAIL: %s" % label)
		_all_passed = false
