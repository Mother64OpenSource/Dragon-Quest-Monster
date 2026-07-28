class_name BattleAudio
extends Node

## Battle sound-effect handler -- scoped to being inside a single battle (not
## a project-wide autoload), one dedicated AudioStreamPlayer per effect so
## an overlapping pair (rare, since _on_turn_resolved awaits each event's
## animation before starting the next) never steals a still-playing sound's
## player out from under it.
##
## Every real .wav was dropped straight into the project folder outside
## Godot's editor-driven import pipeline (no .import file gets generated for
## it), the same class of problem this project already hit for the scribble
## monster art and the battle theme music -- see
## ArtStylePreferenceManager/BattleMusicManager's own doc comments. Unlike
## those two, no manual byte-reading is needed here:
## AudioStreamWAV.load_from_file() (Godot 4.3+) reads a real .wav straight
## off disk on its own, so _load_sfx() just calls that directly. A missing
## file (or a slot with no mapped .wav at all, like menu_select below)
## leaves its stream null, and _play() already no-ops on a null stream, so
## this ships safely even if a file is ever removed.

const SFX_DIR := "res://assets/audio/sfx/"

@onready var _attack_player_weapon: AudioStreamPlayer = $WeaponAttackPlayer
@onready var _attack_player_natural: AudioStreamPlayer = $NaturalAttackPlayer
@onready var _attack_player_cast: AudioStreamPlayer = $CastPlayer
@onready var _hit_player: AudioStreamPlayer = $HitPlayer
@onready var _critical_hit_player: AudioStreamPlayer = $CriticalHitPlayer
@onready var _dodge_player: AudioStreamPlayer = $DodgePlayer
@onready var _miss_player: AudioStreamPlayer = $MissPlayer
@onready var _faint_player: AudioStreamPlayer = $FaintPlayer
@onready var _buff_player: AudioStreamPlayer = $BuffPlayer
@onready var _debuff_player: AudioStreamPlayer = $DebuffPlayer
@onready var _poison_hit_player: AudioStreamPlayer = $PoisonHitPlayer
@onready var _sleep_hit_player: AudioStreamPlayer = $SleepHitPlayer
@onready var _guard_player: AudioStreamPlayer = $GuardPlayer
@onready var _heal_player: AudioStreamPlayer = $HealPlayer
@onready var _enter_battle_player: AudioStreamPlayer = $EnterBattlePlayer
@onready var _forfeit_player: AudioStreamPlayer = $ForfeitPlayer
@onready var _menu_select_player: AudioStreamPlayer = $MenuSelectPlayer

var _weapon_attack_stream: AudioStream
var _natural_attack_stream: AudioStream
var _cast_stream: AudioStream
var _hit_stream: AudioStream
var _critical_hit_stream: AudioStream
var _dodge_stream: AudioStream
var _miss_stream: AudioStream
var _faint_stream: AudioStream
var _buff_stream: AudioStream
var _debuff_stream: AudioStream
var _poison_hit_stream: AudioStream
var _sleep_hit_stream: AudioStream
var _guard_stream: AudioStream
var _heal_stream: AudioStream
var _enter_battle_stream: AudioStream
## No supplied .wav maps cleanly onto a plain menu click -- left null on
## purpose (see class doc comment) rather than force-fitting one of the
## battle sounds where it doesn't belong.
var _menu_select_stream: AudioStream
## Repurposed from the source game's "escape" cue -- this engine has no
## Flee command (removed entirely, see wiki/log.md), so the closest actual
## equivalent moment is forfeiting out of the battle.
var _forfeit_stream: AudioStream

func _ready() -> void:
	_weapon_attack_stream = _load_sfx("weapon_attack.wav")
	_natural_attack_stream = _load_sfx("natural_attack.wav")
	_cast_stream = _load_sfx("cast.wav")
	_hit_stream = _load_sfx("hit.wav")
	_critical_hit_stream = _load_sfx("critical_hit.wav")
	_dodge_stream = _load_sfx("dodge.wav")
	_miss_stream = _load_sfx("miss.wav")
	_faint_stream = _load_sfx("faint.wav")
	_buff_stream = _load_sfx("buff.wav")
	_debuff_stream = _load_sfx("debuff.wav")
	_poison_hit_stream = _load_sfx("poison_hit.wav")
	_sleep_hit_stream = _load_sfx("sleep_hit.wav")
	_guard_stream = _load_sfx("guard.wav")
	_heal_stream = _load_sfx("heal.wav")
	_enter_battle_stream = _load_sfx("enter_battle.wav")
	_forfeit_stream = _load_sfx("forfeit.wav")

## skill_type is SkillData's real "Type" column (Spell/Slash/Body/Dance/
## Breath/Other, see skill_data.gd) -- Spell plays the incantation cue,
## Slash (a weapon strike) plays the weapon swing, everything else
## (Body/Breath/Dance/Other -- a monster's own natural attack) falls back
## to the natural-attack cue.
func play_attack(skill_type: String) -> void:
	match skill_type:
		"Spell":
			_play(_attack_player_cast, _cast_stream)
		"Slash":
			_play(_attack_player_weapon, _weapon_attack_stream)
		_:
			_play(_attack_player_natural, _natural_attack_stream)

func play_hit(is_critical: bool) -> void:
	if is_critical:
		_play(_critical_hit_player, _critical_hit_stream)
	else:
		_play(_hit_player, _hit_stream)

## A dodge/block -- damage was rolled but fully negated (see
## DamageAppliedEvent.was_negated) -- distinct from a missed attack roll.
func play_dodge() -> void:
	_play(_dodge_player, _dodge_stream)

func play_miss() -> void:
	_play(_miss_player, _miss_stream)

func play_faint() -> void:
	_play(_faint_player, _faint_stream)

## delta > 0 is a buff, delta < 0 is a debuff, delta == 0 (a stat already
## maxed/floored, see StatChangedEvent.delta_applied) plays nothing since
## nothing actually changed.
func play_stat_changed(delta: int) -> void:
	if delta > 0:
		_play(_buff_player, _buff_stream)
	elif delta < 0:
		_play(_debuff_player, _debuff_stream)

## Only poison and sleep among the 9 real status ailments (see
## database/status_defs) have a matching "_HIT" infliction cue among the
## supplied sounds -- every other status_id plays nothing rather than
## borrowing a mismatched sound.
func play_status_applied(status_id: String) -> void:
	match status_id:
		"poison":
			_play(_poison_hit_player, _poison_hit_stream)
		"sleep":
			_play(_sleep_hit_player, _sleep_hit_stream)

func play_guard() -> void:
	_play(_guard_player, _guard_stream)

func play_heal() -> void:
	_play(_heal_player, _heal_stream)

## Repurposed from the source game's Zoom/"Rura" teleport-spell cue -- this
## engine has no in-battle Zoom skill for it to genuinely belong to (no
## overworld to warp around in), but it reads just as well as the sound of
## a fresh monster warping into an empty slot (see MonsterEnteredEvent,
## fired here only for a mid-battle faint backfill -- the initial multi-
## monster send-out at battle start is narrated only, never animated/
## sounded, to avoid several of these firing across at once).
func play_enter_battle() -> void:
	_play(_enter_battle_player, _enter_battle_stream)

func play_forfeit() -> void:
	_play(_forfeit_player, _forfeit_stream)

func play_menu_select() -> void:
	_play(_menu_select_player, _menu_select_stream)

func _load_sfx(file_name: String) -> AudioStream:
	var abs_path := ProjectSettings.globalize_path(SFX_DIR + file_name)
	if not FileAccess.file_exists(abs_path):
		push_warning("BattleAudio: sfx file not found at %s" % abs_path)
		return null
	return AudioStreamWAV.load_from_file(abs_path)

func _play(player: AudioStreamPlayer, stream: AudioStream) -> void:
	if stream == null:
		return
	player.stream = stream
	player.play()
