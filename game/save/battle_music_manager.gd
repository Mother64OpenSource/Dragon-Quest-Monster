class_name BattleMusicManager
extends Node

## Loops a single shared battle theme track for as long as at least one
## battle tab (local hotseat's P1/P2, or an online battle) is open --
## registered as an autoload (project.godot) so exactly one
## AudioStreamPlayer ever exists regardless of how many battle tabs are
## open at once. A local hotseat battle has TWO BattleSideView tabs
## sharing one BattleController; each tab's own setup() calls
## play_battle_theme() once, so without the open-tab counter below the
## same looping track would start twice (once per tab) and audibly phase
## against itself. play_battle_theme() is also idempotent on its own
## (checks _player.playing first) as a second line of defense.
##
## Loaded via a plain load() -- battle_theme.mp3 now has a real .import
## file (an editor filesystem rescan picked it up along with every other
## asset added directly to disk outside the import pipeline, see
## wiki/log.md), so the standard resource loader resolves it correctly in
## both the editor and an exported build. An earlier version of this class
## bypassed load() with a raw FileAccess byte-read specifically because
## THAT rescan hadn't happened yet -- keep that workaround in mind (see
## ArtStylePreferenceManager/BattleAudio) if a newly-added asset ever shows
## the same "loads fine in editor, missing once exported" symptom again;
## the real fix is re-running the rescan so it gets a proper .import, not
## reintroducing the bypass.

const THEME_PATH := "res://assets/audio/battle_theme.mp3"
const PREF_PATH := "user://music_volume_preference.json"
## AudioStreamPlayer.volume_db is logarithmic and unbounded (0.0 linear
## maps to -inf dB) -- mapping the slider's 0.0-1.0 linearly onto a fixed
## dB range instead avoids that edge case entirely and is plenty for a
## background-music slider (full mutes to "quiet," not literal silence,
## which is a fine trade-off here).
const MIN_VOLUME_DB := -40.0
const MAX_VOLUME_DB := 0.0

var volume: float = 0.7

var _player: AudioStreamPlayer
var _open_battle_tab_count := 0

func _ready() -> void:
	_load_volume()
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_apply_volume()

	var stream: AudioStreamMP3 = load(THEME_PATH)
	if stream != null:
		stream.loop = true
		_player.stream = stream
	else:
		push_warning("BattleMusicManager: battle theme file not found at %s" % THEME_PATH)

## Called once from every battle tab's own setup() -- safe to call more
## than once for the same battle (two hotseat tabs) or across several
## different battles in a row (a new battle while one's already playing
## just keeps the same loop going rather than restarting it).
func play_battle_theme() -> void:
	_open_battle_tab_count += 1
	if _player.stream != null and not _player.playing:
		_player.play()

## Called once from MainShell whenever a battle tab closes. Only actually
## stops the music once EVERY battle tab that was counted via
## play_battle_theme() has closed -- a hotseat battle's second tab
## closing while the first is still open must not cut the music.
func battle_tab_closed() -> void:
	_open_battle_tab_count = maxi(0, _open_battle_tab_count - 1)
	if _open_battle_tab_count == 0:
		_player.stop()

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_save_volume()

func _apply_volume() -> void:
	if _player != null:
		_player.volume_db = lerpf(MIN_VOLUME_DB, MAX_VOLUME_DB, volume)

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
