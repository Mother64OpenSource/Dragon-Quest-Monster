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
## A bigger spread than the first pass -- "1 slot small, 2 clearly bigger,
## 3 bigger still, 4 biggest" needs each tier to read as a real size jump
## at a glance, not a subtle ~20% difference.
const SLOT_TARGET_HEIGHT := {1: 0.45, 2: 0.8, 3: 1.15, 4: 1.55}
const DEFAULT_TARGET_HEIGHT := 0.45

## A visible formation-grid outline on the ground -- one bordered box per
## anchor (matches the spacing between adjacent Marker3Ds, 1.2 units, minus
## a small gap so neighboring tiles read as separate cells), so a player
## can see where each of the 4 slots per side actually is instead of it
## being purely implicit. Built from four thin, unshaded BoxMesh "bars"
## forming a picture-frame outline rather than a filled tile, so it reads
## as a line marking on the sand rather than a solid platform.
const TILE_WIDTH := 1.05
const TILE_DEPTH := 0.9
const TILE_BORDER_THICKNESS := 0.05
const TILE_BORDER_HEIGHT := 0.02
const TILE_GROUND_Y := 0.01
const TILE_BORDER_COLOR := Color(0.5, 0.32, 0.2, 0.85)
const FALLBACK_PIXEL_SIZE := 0.006  # only used if a sprite has no texture at all
## Alpha 0, not just dimmed -- a fainted monster should actually disappear,
## not linger darkened-but-visible. Kept invisible rather than freed
## outright, since a fainted-but-not-yet-backfilled monster (no living
## reserve left) still occupies its slot and gets re-synced every refresh;
## if this stayed opaque, animate_faint()'s fade-out would get undone the
## moment the next _refresh() ran and re-applied this constant.
const FAINTED_MODULATE := Color(0.35, 0.35, 0.35, 0)
const ACTIVE_MODULATE := Color(1, 1, 1, 1)

## Attacking a real target: step most of the way toward them (not all the
## way -- overlapping the two sprites would look like a collision, not an
## attack) with a small hop, then back to the resting spot.
const LUNGE_FRACTION := 0.55
const LUNGE_HOP_HEIGHT := 0.15
const LUNGE_OUT_TIME := 0.18
const LUNGE_BACK_TIME := 0.18

## How long a fainted monster takes to fade out of view once its
## MonsterFaintedEvent is animated.
const FAINT_FADE_TIME := 0.5

## A short-lived callout (e.g. "Miss!"/"Critical!") floating above a
## sprite's head, rising and fading over this long before freeing itself.
const FLOATING_TEXT_RISE_HEIGHT := 0.35
const FLOATING_TEXT_DURATION := 0.85
const FLOATING_TEXT_FONT_SIZE := 40
const FLOATING_TEXT_OUTLINE_SIZE := 10
const FLOATING_TEXT_GAP_ABOVE_HEAD := 0.12
## Smaller than Sprite3D's own default -- a flat font_size in pixels needs a
## much finer world-units-per-pixel ratio than a full sprite texture does, or
## the callout renders far taller than the monster it's floating above.
const FLOATING_TEXT_PIXEL_SIZE := 0.004
const MISS_TEXT_COLOR := Color(0.88, 0.88, 0.92, 1)
const CRITICAL_TEXT_COLOR := Color(1.0, 0.78, 0.15, 1)
## A direct hit's plain damage number -- distinct from CRITICAL_TEXT_COLOR so
## a glance at the color alone tells crit from normal.
const DAMAGE_TEXT_COLOR := Color(0.95, 0.35, 0.3, 1)
## Poison/status-tick damage -- a sickly violet, distinct from a direct hit's
## red so the source of the damage reads at a glance without parsing text.
const STATUS_DAMAGE_TEXT_COLOR := Color(0.64, 0.4, 0.8, 1)

## A persistent name + HP bar hovering above each monster's own head --
## unlike show_floating_text() (a one-shot callout that frees itself),
## these live for as long as the monster's own sprite does and get updated
## in place every _sync_side() refresh. Built from flat, unshaded,
## billboarded quads (the same "flat colored mesh" idiom the ground tile
## outlines above already use in this file) rather than another Sprite3D,
## since a QuadMesh's own `size` can be resized directly in world units for
## the HP fill's shrinking width -- no pixel_size/texture-aspect math the
## way a Sprite3D-based bar would need. Deliberately translucent (see
## HP_BAR_ALPHA/NAME_LABEL_ALPHA) rather than solid, so it reads as a HUD
## overlay rather than a piece of the arena itself.
const HP_BAR_WIDTH := 0.5
const HP_BAR_HEIGHT := 0.06
const HP_BAR_GAP_ABOVE_HEAD := 0.14
const HP_BAR_ALPHA := 0.78
const HP_BAR_BG_COLOR := Color(0.05, 0.05, 0.07, 0.6)
const HP_BAR_GREEN := Color(0.36, 0.72, 0.4, HP_BAR_ALPHA)
const HP_BAR_AMBER := Color(0.85, 0.7, 0.25, HP_BAR_ALPHA)
const HP_BAR_RED := Color(0.8, 0.28, 0.28, HP_BAR_ALPHA)
const NAME_LABEL_GAP_ABOVE_BAR := 0.05
const NAME_LABEL_FONT_SIZE := 32
const NAME_LABEL_PIXEL_SIZE := 0.0032
const NAME_LABEL_ALPHA := 0.85

## Self-targeted skills have no "enemy" to step toward -- just a small
## bob in place instead.
const BOB_HEIGHT := 0.3
const BOB_UP_TIME := 0.15
const BOB_DOWN_TIME := 0.15

## Idle cinematic camera drift: ease from the authored Camera3D rest pose
## into a slightly closer/offset "cinematic" pose, then ease back -- purely
## atmospheric, runs continuously in the background and never affects
## gameplay (nothing 3D is ever clicked here anyway). IDLE_CAMERA_HOLD_TIME
## is deliberately 0 -- the camera should never actually sit still between
## moves, only ever be transitioning smoothly from one cinematic move into
## the next (in various directions) for the whole time it isn't animating
## an attack; each move's own final leg already eases back through the
## rest pose as a momentary waypoint (not a pause) before immediately
## departing on the next randomly-picked move. The offset is expressed in
## the camera's own local basis (Transform3D.translated()), not world
## axes, so it always reads as "push in and drift sideways from wherever
## the camera is currently looking" regardless of the authored rest angle.
const IDLE_CAMERA_HOLD_TIME := 0.0
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

## Also occasional (see RISE_CHANCE): the camera rises straight up while
## continuously re-aiming at RISE_LOOK_TARGET (roughly monster height, at
## the midpoint between the two rows) via look_at() every step, the same
## "can't just lerp a Transform3D, has to re-derive position/orientation
## each step" reasoning the orbit sweep above already uses -- a straight
## Transform3D lerp would tilt the camera smoothly from its start angle to
## its end angle rather than continuously keeping the monsters in frame as
## the height changes. Reads as a crane-style rise that keeps looking down
## on the battlefield, rather than the camera drifting up and losing its
## subject.
const RISE_CHANCE := 0.2
const RISE_HEIGHT := 0.7
const RISE_TIME := 2.5
const RISE_LOOK_TARGET := Vector3(0, 0.6, 0)

## How long an attack's forced return to the main camera angle takes -- fast
## enough that it reads as "the camera snaps to attention" rather than
## delaying the attack itself, but not so instant it looks like a hard cut.
const ATTACK_CAMERA_RESET_TIME := 0.25

var _sprites: Dictionary = {}   # instance_id (int) -> Sprite3D
var _tweens: Dictionary = {}    # instance_id (int) -> Tween, so a rapid
                                 # re-fire kills the old one instead of stacking
var _hp_bar_backgrounds: Dictionary = {}  # instance_id (int) -> MeshInstance3D
var _hp_bar_fills: Dictionary = {}        # instance_id (int) -> MeshInstance3D
var _name_labels: Dictionary = {}         # instance_id (int) -> Label3D

## The single authored "main" angle every idle cinematic move eases back to,
## and what an attack forces the camera back to -- captured once at _ready()
## rather than re-read from the live Camera3D each time, since by the time
## an attack needs it the camera itself is usually mid-cinematic-move, not
## sitting at rest.
var _camera_rest_transform: Transform3D
## True for the duration of a single attack's own animation (see
## animate_attack()) -- checked by the idle loop so a new cinematic move
## never starts while an attack is actually playing out.
var _is_attack_animating := false
## Whichever idle-cinematic tween is currently in flight (drift/orbit/rise,
## either leg) -- tracked separately from _tweens (which is keyed per
## monster sprite) so an attack starting mid-cinematic-move can kill it
## immediately instead of waiting for it to finish on its own.
var _idle_tween: Tween = null

@onready var _opp_anchors: Array[Marker3D] = [$OppSlot0, $OppSlot1, $OppSlot2, $OppSlot3]
@onready var _my_anchors: Array[Marker3D] = [$MySlot0, $MySlot1, $MySlot2, $MySlot3]
@onready var _camera: Camera3D = $Camera3D

func _ready() -> void:
	_build_slot_tiles()
	_camera_rest_transform = _camera.transform
	_run_idle_camera_loop()

## One outline per anchor, both rows -- a multi-slot monster doesn't merge
## cells, it just visibly spans however many of these fixed-size tiles its
## (now slot-tier-scaled, see SLOT_TARGET_HEIGHT above) sprite covers when
## centered across them, the same way _anchor_midpoint() already positions
## it.
func _build_slot_tiles() -> void:
	for anchor in _opp_anchors + _my_anchors:
		_add_tile_outline(Vector3(anchor.position.x, TILE_GROUND_Y, anchor.position.z))

func _add_tile_outline(center: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TILE_BORDER_COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var half_w := TILE_WIDTH / 2.0
	var half_d := TILE_DEPTH / 2.0
	var t := TILE_BORDER_THICKNESS

	_add_bar(center + Vector3(0, 0, -half_d), Vector3(TILE_WIDTH, TILE_BORDER_HEIGHT, t), mat)
	_add_bar(center + Vector3(0, 0, half_d), Vector3(TILE_WIDTH, TILE_BORDER_HEIGHT, t), mat)
	_add_bar(center + Vector3(-half_w, 0, 0), Vector3(t, TILE_BORDER_HEIGHT, TILE_DEPTH), mat)
	_add_bar(center + Vector3(half_w, 0, 0), Vector3(t, TILE_BORDER_HEIGHT, TILE_DEPTH), mat)

func _add_bar(bar_position: Vector3, size: Vector3, mat: Material) -> void:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	box.material_override = mat
	box.position = bar_position
	add_child(box)

## Loops for the lifetime of the node -- guarded after every await since
## queue_free() (e.g. a headless test tearing down its BattleSideView, or a
## real battle ending) can free this node mid-wait; resuming into a freed
## instance would error without these checks. Also re-checks
## _is_attack_animating right after the hold, so a hold timer that happens
## to expire while an attack is playing doesn't yank the camera into a
## cinematic move mid-attack -- it just waits out another hold instead.
func _run_idle_camera_loop() -> void:
	while is_instance_valid(self) and is_inside_tree():
		await get_tree().create_timer(IDLE_CAMERA_HOLD_TIME).timeout
		if not is_instance_valid(self) or not is_inside_tree():
			return
		if _is_attack_animating:
			continue

		var roll := randf()
		if roll < ORBIT_CHANCE:
			await _run_orbit_sweep(_camera_rest_transform)
		elif roll < ORBIT_CHANCE + RISE_CHANCE:
			await _run_rise_and_look_down(_camera_rest_transform)
		else:
			await _run_simple_drift(_camera_rest_transform)

func _run_simple_drift(rest_transform: Transform3D) -> void:
	var drifted := rest_transform.translated(IDLE_CAMERA_DRIFT_OFFSET)
	var tween_in := create_tween()
	_idle_tween = tween_in
	tween_in.tween_property(_camera, "transform", drifted, IDLE_CAMERA_DRIFT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween_in.finished
	if not is_instance_valid(self) or not is_inside_tree() or _is_attack_animating:
		return

	var tween_out := create_tween()
	_idle_tween = tween_out
	tween_out.tween_property(_camera, "transform", rest_transform, IDLE_CAMERA_RETURN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween_out.finished

## Rises straight up from the resting height while continuously re-aiming
## at RISE_LOOK_TARGET via look_at() each step -- a plain Transform3D lerp
## would blend smoothly from the start angle to whatever angle looking
## down from the new height would need, rather than actually tracking the
## monsters throughout the rise, so this drives it through tween_method()
## the same way the orbit sweep does.
func _run_rise_and_look_down(rest_transform: Transform3D) -> void:
	var start_pos := rest_transform.origin
	var end_pos := start_pos + Vector3(0, RISE_HEIGHT, 0)
	var tween := create_tween()
	_idle_tween = tween
	tween.tween_method(
		_apply_rise.bind(start_pos, end_pos),
		0.0, 1.0, RISE_TIME
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if not is_instance_valid(self) or not is_inside_tree() or _is_attack_animating:
		return

	var tween_back := create_tween()
	_idle_tween = tween_back
	tween_back.tween_property(_camera, "transform", rest_transform, IDLE_CAMERA_RETURN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween_back.finished

func _apply_rise(t: float, start_pos: Vector3, end_pos: Vector3) -> void:
	if not is_instance_valid(_camera):
		return
	_camera.global_position = start_pos.lerp(end_pos, t)
	_camera.look_at(RISE_LOOK_TARGET, Vector3.UP)

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
	_idle_tween = tween
	tween.tween_method(
		_apply_orbit_angle.bind(start_offset, direction),
		0.0, ORBIT_SWEEP_ANGLE, ORBIT_SWEEP_TIME
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if not is_instance_valid(self) or not is_inside_tree() or _is_attack_animating:
		return

	var tween_back := create_tween()
	_idle_tween = tween_back
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
			_hp_bar_backgrounds.erase(instance_id)
			_hp_bar_fills.erase(instance_id)
			_name_labels.erase(instance_id)

func _sync_side(state: BattleState, side: String, anchors: Array[Marker3D], seen: Dictionary) -> void:
	for slot in range(BattleController.ACTIVE_SLOT_COUNT):
		var monster := state.get_monster_at(side, slot)
		if monster == null or seen.has(monster.instance_id):
			continue
		seen[monster.instance_id] = true

		var span := monster.species.slots
		var sprite := _get_or_create(monster.instance_id, monster.species)
		var ground_pos := _anchor_midpoint(anchors, slot, span)
		# Sprite3D centers its texture on its own position, so placing it at
		# the anchors' authored Y (a fixed 0.6 regardless of the sprite's
		# actual rendered height) left every monster's feet floating well
		# above the ground/tile plane instead of standing on it -- especially
		# once shorter 1-slot monsters got their own smaller normalized
		# height. Standing on the ground means the sprite's BOTTOM edge, not
		# its center, belongs at ground level, so the center needs to sit
		# half a sprite-height above TILE_GROUND_Y instead.
		var rendered_height: float = sprite.pixel_size * sprite.texture.get_height() if sprite.texture != null else DEFAULT_TARGET_HEIGHT
		sprite.global_position = Vector3(ground_pos.x, TILE_GROUND_Y + rendered_height / 2.0, ground_pos.z)
		sprite.modulate = FAINTED_MODULATE if monster.is_fainted() else ACTIVE_MODULATE
		_update_hp_bar(monster.instance_id, monster)

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
	_build_hp_bar_and_name(sprite, instance_id, species)
	return sprite

## Builds the name label and the (background + fill) HP bar quads once per
## sprite, parented to it so they inherit its position automatically --
## _update_hp_bar() below then only ever needs to touch the fill's width/
## color/visibility on each refresh, never recreate anything.
func _build_hp_bar_and_name(sprite: Sprite3D, instance_id: int, species: MonsterSpecies) -> void:
	var rendered_height: float = sprite.pixel_size * sprite.texture.get_height() if sprite.texture != null else DEFAULT_TARGET_HEIGHT
	var bar_y := rendered_height / 2.0 + HP_BAR_GAP_ABOVE_HEAD

	var bg := _make_billboard_quad(Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT), HP_BAR_BG_COLOR)
	bg.position = Vector3(0, bar_y, 0)
	sprite.add_child(bg)
	_hp_bar_backgrounds[instance_id] = bg

	# A small +Z nudge (plus no_depth_test on both, see _make_billboard_quad)
	# keeps the fill drawing in front of the background instead of the two
	# coplanar quads z-fighting.
	var fill := _make_billboard_quad(Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT), HP_BAR_GREEN)
	fill.position = Vector3(0, bar_y, 0.01)
	sprite.add_child(fill)
	_hp_bar_fills[instance_id] = fill

	var name_label := Label3D.new()
	name_label.text = species.display_name
	name_label.font_size = NAME_LABEL_FONT_SIZE
	name_label.pixel_size = NAME_LABEL_PIXEL_SIZE
	name_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	name_label.no_depth_test = true
	name_label.modulate = Color(1, 1, 1, NAME_LABEL_ALPHA)
	name_label.outline_size = 8
	name_label.position = Vector3(0, bar_y + HP_BAR_HEIGHT / 2.0 + NAME_LABEL_GAP_ABOVE_BAR, 0)
	sprite.add_child(name_label)
	_name_labels[instance_id] = name_label

## A flat, unshaded, billboarded quad -- the 3D equivalent of a plain
## colored ColorRect, used for both the HP bar's backdrop and its fill.
func _make_billboard_quad(size: Vector2, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.no_depth_test = true
	mesh_instance.material_override = mat
	return mesh_instance

## Keeps each monster's floating name/HP bar in sync with its real HP --
## called once per _sync_side() refresh, the same cadence the 2D cards'
## own HP readouts already update at. Hidden outright (not faded) once
## fainted -- a defeated monster's HP bar isn't meaningful to keep
## tracking, and animate_faint() already handles the sprite's own gradual
## fade separately; these floating elements have no modulate to inherit
## from the sprite even if we wanted a matching fade, since
## Sprite3D/MeshInstance3D/Label3D are independent VisualInstance3Ds, not
## CanvasItems -- a parent's modulate never cascades to 3D children the
## way it would in 2D.
func _update_hp_bar(instance_id: int, monster: MonsterInstance) -> void:
	var bg: MeshInstance3D = _hp_bar_backgrounds.get(instance_id)
	var fill: MeshInstance3D = _hp_bar_fills.get(instance_id)
	var name_label: Label3D = _name_labels.get(instance_id)
	if bg == null or fill == null or name_label == null:
		return

	var fainted := monster.is_fainted()
	bg.visible = not fainted
	fill.visible = not fainted
	name_label.visible = not fainted
	if fainted:
		return

	var ratio := clampf(float(monster.current_hp) / float(maxi(1, monster.species.base_hp)), 0.0, 1.0)
	var fill_mesh := fill.mesh as QuadMesh
	fill_mesh.size = Vector2(HP_BAR_WIDTH * ratio, HP_BAR_HEIGHT)
	# QuadMesh is centered on its own node origin -- shrinking it would drain
	# from BOTH sides equally, not read as "draining from the right, pinned
	# to the left" the way a real HP bar should. Re-offsetting the node's
	# local X by half the missing width keeps its LEFT edge fixed instead,
	# matching the background's own left edge.
	fill.position.x = -(HP_BAR_WIDTH - HP_BAR_WIDTH * ratio) / 2.0
	var fill_mat := fill.material_override as StandardMaterial3D
	fill_mat.albedo_color = HP_BAR_GREEN if ratio > 0.5 else (HP_BAR_AMBER if ratio > 0.2 else HP_BAR_RED)

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
##
## Also forces the camera back to its authored main angle first (see
## _force_camera_to_main_angle) -- the idle cinematic drift/orbit/rise runs
## continuously and independently the rest of the time, but an attack
## itself should always be shown from the standard viewing angle, never
## mid-cinematic-sweep.
func animate_attack(actor_instance_id: int, target_instance_id: int) -> void:
	var sprite := get_sprite(actor_instance_id)
	if sprite == null:
		return
	_force_camera_to_main_angle()
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
	_is_attack_animating = false

## Interrupts whatever idle cinematic move is currently in flight (if any --
## a no-op kill on an already-finished Tween is harmless) and eases the
## camera back to the authored rest transform. _is_attack_animating stays
## true until the calling animate_attack()'s own tween finishes, so the
## idle loop won't start a NEW cinematic move mid-attack even if its hold
## timer happens to expire at exactly the wrong moment.
func _force_camera_to_main_angle() -> void:
	_is_attack_animating = true
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	var reset_tween := create_tween()
	reset_tween.tween_property(_camera, "transform", _camera_rest_transform, ATTACK_CAMERA_RESET_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## A monster's sprite fades out of view entirely rather than merely
## darkening -- called once, right when its MonsterFaintedEvent is
## animated. Fades from whatever modulate it's currently showing (so a
## fully-visible monster fading straight to gone doesn't visibly "pop" to
## FAINTED_MODULATE's dim tint first), down to fully transparent. A no-op
## if the sprite is already gone (stale event).
func animate_faint(instance_id: int) -> void:
	var sprite := get_sprite(instance_id)
	if sprite == null:
		return
	if _tweens.has(instance_id):
		_tweens[instance_id].kill()

	# Hidden immediately, not faded alongside the sprite -- a defeated
	# monster's HP bar/name isn't meaningful to keep showing, and unlike the
	# sprite itself these have no modulate for a matching tween to even
	# target (see _update_hp_bar's own doc comment on why).
	if _hp_bar_backgrounds.has(instance_id):
		_hp_bar_backgrounds[instance_id].visible = false
	if _hp_bar_fills.has(instance_id):
		_hp_bar_fills[instance_id].visible = false
	if _name_labels.has(instance_id):
		_name_labels[instance_id].visible = false

	var current := sprite.modulate
	var faded := Color(current.r, current.g, current.b, 0.0)
	var tween := create_tween()
	_tweens[instance_id] = tween
	tween.tween_property(sprite, "modulate", faded, FAINT_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished

## A short callout ("Miss!"/"Critical!") floating up from a sprite's own
## head and fading out -- called from BattleSideView._animate_event() once a
## hit's outcome (missed/dodged/crit) is known. Not tracked in _tweens
## (unlike animate_attack/animate_faint): this owns its own standalone
## Label3D node rather than animating a persistent shared sprite, so a
## rapid re-fire (e.g. two hits of a multi-hit skill landing back to back)
## just stacks a second independent callout instead of needing to kill/
## replace anything. A no-op if the target has no sprite (already fainted
## and backfilled away, or a stale event), matching animate_attack()/
## animate_faint()'s own null-safety convention.
func show_floating_text(instance_id: int, text: String, color: Color) -> void:
	var sprite := get_sprite(instance_id)
	if sprite == null:
		return

	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = FLOATING_TEXT_FONT_SIZE
	label.outline_size = FLOATING_TEXT_OUTLINE_SIZE
	label.pixel_size = FLOATING_TEXT_PIXEL_SIZE
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	sprite.add_child(label)

	# Sprite3D centers its texture on its own position (see _sync_side), so
	# the sprite's local origin sits at the vertical MIDPOINT of the
	# rendered image, not its feet -- the top of its head is a further half
	# a rendered-height above that same origin.
	var rendered_height: float = sprite.pixel_size * sprite.texture.get_height() if sprite.texture != null else DEFAULT_TARGET_HEIGHT
	label.position = Vector3(0, rendered_height / 2.0 + FLOATING_TEXT_GAP_ABOVE_HEAD, 0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + FLOATING_TEXT_RISE_HEIGHT, FLOATING_TEXT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, FLOATING_TEXT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
