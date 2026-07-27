class_name BackgroundDisplay
extends Control

## Full-rect background layer for Showdown-style translucent-panel screens.
## Static images (png/jpg/jpeg/webp/bmp) load directly via Image.load(),
## which reads these formats straight off disk without going through
## Godot's resource-import pipeline -- required since an uploaded file
## lives outside res:// and was never imported. .gif files are decoded
## once via GifDecoder and played back by swapping TextureRect.texture on
## a one-shot Timer that restarts itself with each frame's own delay_sec
## (frame delays are rarely uniform across a real GIF).
##
## Falls back to a procedural gradient -- deliberately not bundled
## Showdown art, see wiki/log.md IP note -- whenever no path is set or
## loading fails for any reason.

const STATIC_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "bmp"]
const MIN_FRAME_DELAY_SEC := 0.02

@onready var _texture_rect: TextureRect = $TextureRect
@onready var _frame_timer: Timer = $FrameTimer

var _gif_frames: Array = []
var _gif_frame_index: int = 0

func _ready() -> void:
	_frame_timer.one_shot = true
	_frame_timer.timeout.connect(_on_frame_timer_timeout)
	_show_fallback_gradient()

## path may be a user:// (or absolute) file path, or empty to force the
## fallback gradient.
func set_background_path(path: String) -> void:
	_gif_frames = []
	_frame_timer.stop()

	if path.is_empty() or not FileAccess.file_exists(path):
		_show_fallback_gradient()
		return

	var extension := path.get_extension().to_lower()
	if extension == "gif":
		_load_gif(path)
	elif extension in STATIC_EXTENSIONS:
		_load_static_image(path)
	else:
		push_error("BackgroundDisplay: unsupported background extension '%s'" % extension)
		_show_fallback_gradient()

func _load_static_image(path: String) -> void:
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		push_error("BackgroundDisplay: failed to load image %s (error %d)" % [path, err])
		_show_fallback_gradient()
		return
	_texture_rect.texture = ImageTexture.create_from_image(image)

func _load_gif(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("BackgroundDisplay: failed to open GIF %s" % path)
		_show_fallback_gradient()
		return
	var bytes := file.get_buffer(file.get_length())
	file.close()

	_gif_frames = GifDecoder.decode(bytes)
	if _gif_frames.is_empty():
		push_error("BackgroundDisplay: GIF %s decoded to zero frames" % path)
		_show_fallback_gradient()
		return

	_gif_frame_index = 0
	_show_current_gif_frame()

func _on_frame_timer_timeout() -> void:
	if _gif_frames.is_empty():
		return
	_gif_frame_index = (_gif_frame_index + 1) % _gif_frames.size()
	_show_current_gif_frame()

func _show_current_gif_frame() -> void:
	var frame: GifFrame = _gif_frames[_gif_frame_index]
	_texture_rect.texture = frame.texture
	if _gif_frames.size() > 1:
		_frame_timer.start(maxf(MIN_FRAME_DELAY_SEC, frame.delay_sec))

func _show_fallback_gradient() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.09, 0.11, 0.22))
	gradient.set_color(1, Color(0.32, 0.16, 0.42))
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 4
	gradient_texture.height = 4
	gradient_texture.fill = GradientTexture2D.FILL_LINEAR
	gradient_texture.fill_from = Vector2(0, 0)
	gradient_texture.fill_to = Vector2(1, 1)
	_texture_rect.texture = gradient_texture
