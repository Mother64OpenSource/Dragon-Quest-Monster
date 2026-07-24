class_name BattleArena3D
extends Node3D

## The 3D presentation of the battlefield -- both sides' active monsters
## render here as Sprite3D billboards (the same 2D artwork used everywhere
## else in the app, just placed in a real 3D arena instead of a flat UI
## panel). Embedded inside battle_side_view.tscn's SubViewportContainer;
## nothing here is ever clicked -- all interaction stays on the existing 2D
## OpponentPanel/MyPartyPanel buttons, this is pure display.
##
## Sprites are persistent (instance_id -> Sprite3D), diff-updated in place
## rather than destroyed/rebuilt every sync -- an attack Tween (see
## animate_attack()) targets these exact node instances, and rebuilding
## from scratch every refresh would orphan any tween mid-animation.

## Target on-screen height (world units), keyed by species.slots. Source
## art varies wildly in native resolution/crop (some monsters use a tight
## pixel-sprite, others a much larger fan-art image) -- a single flat
## Sprite3D.pixel_size applied to everyone let whichever monster's source
## image happened to be taller render as visually bigger, regardless of its
## actual slot size (this is exactly what happened with Slime: its
## replacement art is a bigger source image than the monster next to it,
## so it rendered bigger despite being the same 1-slot tier). Computing
## pixel_size per-sprite from the ACTUAL loaded texture's pixel height and
## this target normalizes every monster to a consistent height for its own
## slot tier, with each tier taller than the last; width follows
## automatically since pixel_size scales both axes via the texture's own
## aspect ratio.
const SLOT_TARGET_HEIGHT := {1: 0.5, 2: 0.7, 3: 0.9, 4: 1.1}
const DEFAULT_TARGET_HEIGHT := 0.5
const FALLBACK_PIXEL_SIZE := 0.006  # only used if a sprite has no texture at all
const FAINTED_MODULATE := Color(0.35, 0.35, 0.35, 1)
const ACTIVE_MODULATE := Color(1, 1, 1, 1)

## Attacking a real target: step most of the way toward them (not all the
## way -- overlapping the two sprites would look like a collision, not an
## attack) with a small hop, then back to the resting spot.
const LUNGE_FRACTION := 0.55
const LUNGE_HOP_HEIGHT := 0.15
const LUNGE_OUT_TIME := 0.18
const LUNGE_BACK_TIME := 0.18

## Self-targeted skills have no "enemy" to step toward -- just a small
## bob in place instead.
const BOB_HEIGHT := 0.3
const BOB_UP_TIME := 0.15
const BOB_DOWN_TIME := 0.15

## Idle cinematic camera drift: rest at the authored Camera3D transform for
## a few seconds, ease into a slightly closer/offset "cinematic" pose, hold,
## then ease back -- purely atmospheric, runs continuously in the
## background and never affects gameplay (nothing 3D is ever clicked here
## anyway). The offset is expressed in the camera's own local basis
## (Transform3D.translated()), not world axes, so it always reads as
## "push in and drift sideways from wherever the camera is currently
## looking" regardless of the authored rest angle.
const IDLE_CAMERA_HOLD_TIME := 8.0
const IDLE_CAMERA_DRIFT_TIME := 1.8
const IDLE_CAMERA_RETURN_TIME := 1.8
const IDLE_CAMERA_DRIFT_OFFSET := Vector3(0.12, -0.04, -0.15)

## Occasionally (not every cycle -- see ORBIT_CHANCE), instead of the small
## drift above, the camera sweeps a short arc around a pivot near the
## opponent's row, direction (left/right) chosen at random each time, then
## eases back to the exact resting shot. A pivot near the Opp row (z -1.2)
## rather than the arena's dead center is what makes the sweep read as
## "toward the opponent" rather than an arbitrary spin. ORBIT_SWEEP_ANGLE
## is well short of a full half circle (PI) -- a full 180 degree swing
## proved too dramatic in practice.
const ORBIT_CHANCE := 0.2
const ORBIT_SWEEP_TIME := 2.2
const ORBIT_SWEEP_ANGLE := PI * 0.28
const ORBIT_PIVOT := Vector3(0, 0.6, -0.6)

var _sprites: Dictionary = {}   # instance_id (int) -> Sprite3D
var _tweens: Dictionary = {}    # instance_id (int) -> Tween, so a rapid
                                 # re-fire kills the old one instead of stacking

@onready var _opp_anchors: Array[Marker3D] = [$OppSlot0, $OppSlot1, $OppSlot2, $OppSlot3]
@onready var _my_anchors: Array[Marker3D] = [$MySlot0, $MySlot1, $MySlot2, $MySlot3]
@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	_run_idle_camera_loop()

## Loops for the lifetime of the node -- guarded after every await since
## queue_free() (e.g. a headless test tearing down its BattleSideView, or a
## real battle ending) can free this node mid-wait; resuming into a freed
## instance would error without these checks.
func _run_idle_camera_loop() -> void:
	var rest_transform := _camera.transform
	while is_instance_valid(self) and is_inside_tree():
		await get_tree().create_timer(IDLE_CAMERA_HOLD_TIME).timeout
		if not is_instance_valid(self) or not is_inside_tree():
			return

		if randf() < ORBIT_CHANCE:
			await _run_orbit_sweep(rest_transform)
		else:
			await _run_simple_drift(rest_transform)

func _run_simple_drift(rest_transform: Transform3D) -> void:
	var drifted := rest_transform.translated(IDLE_CAMERA_DRIFT_OFFSET)
	var tween_in := create_tween()
	tween_in.tween_property(_camera, "transform", drifted, IDLE_CAMERA_DRIFT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween_in.finished
	if not is_instance_valid(self) or not is_inside_tree():
		return

	var tween_out := create_tween()
	tween_out.tween_property(_camera, "transform", rest_transform, IDLE_CAMERA_RETURN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween_out.finished

## A straight Transform3D lerp between rest and some other pose would cut a
## straight line through the arena, not curve around it -- so this drives
## the sweep through tween_method() instead, re-deriving the camera's
## position each step by rotating its start offset from ORBIT_PIVOT around
## the vertical axis, and re-aiming at the pivot every step via look_at()
## so the shot stays framed on the opponent's side throughout the swing.
func _run_orbit_sweep(rest_transform: Transform3D) -> void:
	var start_offset := rest_transform.origin - ORBIT_PIVOT
	var direction := 1.0 if randf() < 0.5 else -1.0
	var tween := create_tween()
	tween.tween_method(
		_apply_orbit_angle.bind(start_offset, direction),
		0.0, ORBIT_SWEEP_ANGLE, ORBIT_SWEEP_TIME
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if not is_instance_valid(self) or not is_inside_tree():
		return

	var tween_back := create_tween()
	tween_back.tween_property(_camera, "transform", rest_transform, IDLE_CAMERA_RETURN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween_back.finished

func _apply_orbit_angle(angle: float, start_offset: Vector3, direction: float) -> void:
	if not is_instance_valid(_camera):
		return
	_camera.global_position = ORBIT_PIVOT + start_offset.rotated(Vector3.UP, angle * direction)
	_camera.look_at(ORBIT_PIVOT, Vector3.UP)

## Diff-updates persistent sprites against current battle state -- call from
## BattleSideView._refresh(), same place/frequency the 2D card grids rebuild.
## `my_side` lets each BattleSideView's own Arena orient itself from its own
## window's perspective, exactly like MyPartyPanel/OpponentPanel already do
## independently per view today.
func sync_monsters(state: BattleState, my_side: String) -> void:
	var opponent_side := "side_b" if my_side == "side_a" else "side_a"
	var seen := {}
	_sync_side(state, my_side, _my_anchors, seen)
	_sync_side(state, opponent_side, _opp_anchors, seen)

	for instance_id in _sprites.keys().duplicate():
		if not seen.has(instance_id):
			_sprites[instance_id].queue_free()
			_sprites.erase(instance_id)

func _sync_side(state: BattleState, side: String, anchors: Array[Marker3D], seen: Dictionary) -> void:
	for slot in range(BattleController.ACTIVE_SLOT_COUNT):
		var monster := state.get_monster_at(side, slot)
		if monster == null or seen.has(monster.instance_id):
			continue
		seen[monster.instance_id] = true

		var span := monster.species.slots
		var sprite := _get_or_create(monster.instance_id, monster.species)
		sprite.global_position = _anchor_midpoint(anchors, slot, span)
		sprite.modulate = FAINTED_MODULATE if monster.is_fainted() else ACTIVE_MODULATE

## The arithmetic midpoint of the anchors a multi-slot monster spans --
## mirrors the 2D cards' "wider card centered across its slots" look.
func _anchor_midpoint(anchors: Array[Marker3D], slot: int, span: int) -> Vector3:
	var count := mini(span, anchors.size() - slot)
	var sum := Vector3.ZERO
	for i in range(slot, slot + count):
		sum += anchors[i].global_position
	return sum / maxf(1.0, float(count))

func _get_or_create(instance_id: int, species: MonsterSpecies) -> Sprite3D:
	if _sprites.has(instance_id):
		return _sprites[instance_id]
	var sprite := Sprite3D.new()
	# BILLBOARD_FIXED_Y (not the full BILLBOARD_ENABLED) rotates the sprite
	# to face the camera around the Y axis only, keeping it upright on the
	# ground -- full billboarding also tilts with the camera's pitch, which
	# looks wrong for something standing on a floor.
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	if not species.sprite_path.is_empty():
		sprite.texture = load(species.sprite_path)
	sprite.pixel_size = _pixel_size_for(sprite.texture, species.slots)
	add_child(sprite)
	_sprites[instance_id] = sprite
	return sprite

## Derives pixel_size from the ACTUAL loaded texture's pixel height so every
## monster renders at the target height for its own slot tier, regardless
## of how many pixels tall its particular source image happens to be.
func _pixel_size_for(texture: Texture2D, slots: int) -> float:
	if texture == null or texture.get_height() <= 0:
		return FALLBACK_PIXEL_SIZE
	var target_height: float = SLOT_TARGET_HEIGHT.get(slots, DEFAULT_TARGET_HEIGHT)
	return target_height / float(texture.get_height())

## null if not found (fainted-and-backfilled, or a stale event) -- callers
## check this rather than assuming a sprite always exists.
func get_sprite(instance_id: int) -> Sprite3D:
	return _sprites.get(instance_id)

## Every attack visibly steps its actor toward the target and back,
## unconditionally (hit, miss, fizzle) -- a no-op if the actor has no
## sprite (already fainted and backfilled away, or a stale event). Awaits
## the full animation so callers (BattleSideView's per-event loop) can play
## a round's attacks out one at a time instead of all at once.
func animate_attack(actor_instance_id: int, target_instance_id: int) -> void:
	var sprite := get_sprite(actor_instance_id)
	if sprite == null:
		return
	if _tweens.has(actor_instance_id):
		_tweens[actor_instance_id].kill()

	var base_pos := sprite.position
	var tween := create_tween()
	_tweens[actor_instance_id] = tween

	var target_sprite := get_sprite(target_instance_id) if target_instance_id != actor_instance_id else null
	if target_sprite != null:
		var lunge_pos := base_pos.lerp(to_local(target_sprite.global_position), LUNGE_FRACTION) + Vector3.UP * LUNGE_HOP_HEIGHT
		tween.tween_property(sprite, "position", lunge_pos, LUNGE_OUT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "position", base_pos, LUNGE_BACK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(sprite, "position:y", base_pos.y + BOB_HEIGHT, BOB_UP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "position:y", base_pos.y, BOB_DOWN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await tween.finished
