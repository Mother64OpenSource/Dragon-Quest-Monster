class_name SfxVolumeManager
extends Node

## Persisted volume for one-shot battle sound effects (BattleAudio), kept
## as its own slider separate from BattleMusicManager's -- sfx and music
## are independent things the player might want at different levels (e.g.
## music low, hit/crit sounds still clear). Registered as an autoload
## ("SfxVolume") specifically so every BattleAudio instance (one per open
## battle tab, see battle_side_view.tscn's "Audio" child) reads the same
## live value at the moment each sound actually plays, rather than each
## instance baking in its own stale copy at _ready() -- adjusting the
## slider in one tab's UI takes effect for sound played from every tab
## immediately, the same as BattleMusicManager's single shared player
## already guarantees for music.

const PREF_PATH := "user://sfx_volume_preference.json"
## Same fixed dB range and lerpf() reasoning as BattleMusicManager (avoids
## linear_to_db()'s -inf-at-zero edge case) -- kept identical across both
## sliders so "halfway" reads the same on each.
const MIN_VOLUME_DB := -40.0
const MAX_VOLUME_DB := 0.0

var volume: float = 0.7

func _ready() -> void:
	_load_volume()

## Read by BattleAudio._play() on every single sound, not cached -- see
## class doc comment for why that matters across multiple tabs.
func get_volume_db() -> float:
	return lerpf(MIN_VOLUME_DB, MAX_VOLUME_DB, volume)

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_save_volume()

func _load_volume() -> void:
	if not FileAccess.file_exists(PREF_PATH):
		return
	var file := FileAccess.open(PREF_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("volume"):
		volume = clampf(float(parsed["volume"]), 0.0, 1.0)

func _save_volume() -> void:
	var file := FileAccess.open(PREF_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"volume": volume}))
	file.close()
