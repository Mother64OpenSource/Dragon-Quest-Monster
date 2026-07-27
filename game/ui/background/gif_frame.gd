class_name GifFrame
extends RefCounted

var texture: ImageTexture
var delay_sec: float

func _init(p_texture: ImageTexture, p_delay_sec: float) -> void:
	texture = p_texture
	delay_sec = p_delay_sec
