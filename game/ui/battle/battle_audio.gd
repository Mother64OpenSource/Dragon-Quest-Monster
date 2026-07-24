class_name BattleAudio
extends Node

## Battle sound hook points -- scoped to being inside a single battle (not a
## project-wide autoload), everything on the default Master bus (no mixing
## requirement yet). A null exported stream is a silent no-op, so this ships
## with zero actual sound and breaks nothing: drop .wav/.ogg/.mp3 files
## anywhere under res://, then assign them to the four slots below in the
## Godot editor's Inspector -- no code changes needed to wire real audio in.

@export var attack_stream: AudioStream
@export var hit_stream: AudioStream
@export var faint_stream: AudioStream
@export var menu_select_stream: AudioStream

@onready var _attack_player: AudioStreamPlayer = $AttackPlayer
@onready var _hit_player: AudioStreamPlayer = $HitPlayer
@onready var _faint_player: AudioStreamPlayer = $FaintPlayer
@onready var _menu_select_player: AudioStreamPlayer = $MenuSelectPlayer

func play_attack() -> void:
	_play(_attack_player, attack_stream)

func play_hit() -> void:
	_play(_hit_player, hit_stream)

func play_faint() -> void:
	_play(_faint_player, faint_stream)

func play_menu_select() -> void:
	_play(_menu_select_player, menu_select_stream)

func _play(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if stream == null:
		return
	player.stream = stream
	player.play()
