class_name BattleSideView
extends Control

## Per-window battle UI for one side. Two of these exist per battle (one per
## OS window), both pointed at the same BattleController -- there is no
## networking, they're just two Control trees sharing one process's memory.
##
## The battlefield itself renders in a real 3D arena (BattleArena3D, embedded
## via a SubViewportContainer) -- both sides' monsters appear there as
## billboarded 2D sprites. The 2D "OpponentPanel"/"MyPartyPanel" rows below
## it are unchanged in purpose (HP/MP readouts, click-to-target) -- nothing
## in the 3D view is ever clickable, it's pure display.
##
## Layout: a "battlefield" facing the opponent's up to 4 active monsters, a
## command panel that cycles through each of your not-yet-submitted active
## slots in turn, and "Your Party" split into Main Party (your active
## lineup, up to 4 slot-points) and Second Party (bench, also up to 4
## slot-points -- see TeamFormationLayout in the team builder for the same
## slot-point-capacity rule applied at save time). Cards render once per
## unique active monster (not once per raw slot index) in an HFlowContainer,
## wide in proportion to that monster's own species.slots (1-4) -- a 2-slot
## monster's card is twice as wide as a 1-slot one, a 4-slot monster's card
## fills a whole row alone. A rigid fixed-column grid can't cleanly
## represent an odd slot count like 3-of-4 as a rectangle, so a flow layout
## that just wraps naturally was simpler and more honest than fighting grid
## geometry.
##
## Dragging a card between Main Party and Second Party stages a proposed
## formation change -- nothing is submitted to the engine until "Apply
## Formation" is pressed. Staging (not immediate commit) is deliberate: an
## earlier version called submit_swap() straight from the drop handler,
## which locks that raw slot in for the round the instant you drop (the
## engine's own "one action per slot per round" rule) -- meaning you could
## only ever swap each slot once, with no way to compare a few different
## combinations before committing. Now you can rearrange freely (bench
## monster X onto slot 0, then change your mind and put Y there instead,
## drag someone else out, etc.) and only the FINAL staged arrangement gets
## submitted, all at once, when you press Apply. This replaces the old
## "Orders" command entirely. Dragging only while _mode == MODE_MENU (not
## mid skill-pick/target-pick).
##
## "Fight" drills into a skill list; picking a single-enemy skill switches
## the battlefield into target-picking mode (only living enemy cards are
## clickable). "Defend" (halves incoming damage until this monster's own
## next action -- see DamageEffect/ActionExecutor) submits immediately, no
## sub-menu, same as Forfeit. "Tactics" remains an inert stub. Built
## from this project's own default-theme controls and monster icons, not a
## copy of any specific game's actual art/assets.

## Emitted by the result panel's own Back button, once the battle is
## actually over (win/lose/forfeit/disconnect all funnel through the same
## panel) -- whoever hosts this view (a MainShell tab today) should
## close/free it entirely, not this screen itself. Switching back to Home
## mid-battle needs no button/signal of its own here -- the host's own tab
## strip already does that non-destructively (click the Home tab), the
## same way Showdown's own battle rooms work.
signal close_requested()

const CARD_BASE_WIDTH := 140

const MODE_MENU := "menu"
const MODE_SKILLS := "skills"
const MODE_TARGETING := "targeting"

var _controller: BattleController
var _my_side: String
var _skill_db: SkillDatabase
var _current_slot: int = -1
var _mode: String = MODE_MENU
var _pending_skill_id: String = ""

## The proposed active lineup, per raw slot index -- instance_id, or -1 for
## empty. Purely local UI state until "Apply Formation" is pressed; see the
## class doc above for why staging replaced immediately calling
## submit_swap() from the drop handler. Synced from the engine's actual
## current formation in setup() and at the start of every new round
## (_on_turn_resolved) -- NOT on every _refresh(), so staged edits persist
## across, e.g., Fight-commanding an unrelated slot mid-round.
var _staged_active_ids: Array[int] = []

@onready var _opponent_panel_grid: HFlowContainer = $Root/MainColumn/Battlefield/MarginContainer/VBox/OpponentPanel
@onready var _battlefield_header: Label = $Root/MainColumn/Battlefield/MarginContainer/VBox/HeaderRow/BattlefieldHeader
@onready var _arena: BattleArena3D = $Root/MainColumn/Battlefield/MarginContainer/VBox/ArenaViewportContainer/ArenaViewport/Arena
@onready var _turn_counter_label: Label = $Root/MainColumn/Battlefield/MarginContainer/VBox/HeaderRow/TurnCounterLabel
@onready var _audio: BattleAudio = $Audio
@onready var _current_slot_label: Label = $Root/MainColumn/BottomPanel/CommandPanel/CommandPanelVBox/CurrentSlotLabel
@onready var _fight_button: Button = $Root/MainColumn/BottomPanel/CommandPanel/CommandPanelVBox/FightButton
@onready var _defend_button: Button = $Root/MainColumn/BottomPanel/CommandPanel/CommandPanelVBox/DefendButton
@onready var _tactics_button: Button = $Root/MainColumn/BottomPanel/CommandPanel/CommandPanelVBox/TacticsButton
@onready var _forfeit_button: Button = $Root/MainColumn/BottomPanel/CommandPanel/CommandPanelVBox/ForfeitButton
@onready var _forfeit_confirm_dialog: ConfirmationDialog = $ForfeitConfirmDialog
@onready var _actions_scroll: ScrollContainer = $Root/MainColumn/BottomPanel/CommandPanel/CommandPanelVBox/ActionsScroll
@onready var _actions_box: VBoxContainer = $Root/MainColumn/BottomPanel/CommandPanel/CommandPanelVBox/ActionsScroll/ActionsBox
@onready var _actions_back_button: Button = $Root/MainColumn/BottomPanel/CommandPanel/CommandPanelVBox/ActionsScroll/ActionsBox/BackButton
@onready var _main_party_row: HFlowContainer = $Root/MainColumn/BottomPanel/MyPartyPanel/MyPartyVBox/MainPartyRow
@onready var _second_party_row: HFlowContainer = $Root/MainColumn/BottomPanel/MyPartyPanel/MyPartyVBox/SecondPartyRow
@onready var _apply_formation_button: Button = $Root/MainColumn/BottomPanel/MyPartyPanel/MyPartyVBox/ApplyFormationButton
@onready var _waiting_label: Label = $Root/MainColumn/WaitingLabel
@onready var _targeting_label: Label = $Root/MainColumn/Battlefield/MarginContainer/VBox/TargetingLabel
@onready var _log_label: Label = $Root/LogPanel/LogVBox/LogScroll/LogLabel
@onready var _log_scroll: ScrollContainer = $Root/LogPanel/LogVBox/LogScroll
@onready var _result_panel: PanelContainer = $Root/MainColumn/ResultPanel
@onready var _result_label: Label = $Root/MainColumn/ResultPanel/VBoxContainer/ResultLabel
@onready var _back_button: Button = $Root/MainColumn/ResultPanel/VBoxContainer/BackButton
## Looked up via get_node(), not the bare "ArtStylePreference" identifier --
## matches this project's own NetworkManager convention (see
## network_setup_screen.gd's _network var).
@onready var _art_style: ArtStylePreferenceManager = get_node("/root/ArtStylePreference")
@onready var _background_display: BackgroundDisplay = $BackgroundDisplay

func _ready() -> void:
	# Reads the same shared preference TeamBuilderScreen's "Change
	# Background..." button writes -- whatever the player already chose for
	# Home shows through here too, rather than the battle screen having its
	# own separate (and by default empty) background choice.
	var background_pref_manager := BackgroundPreferenceManager.new()
	_background_display.set_background_path(background_pref_manager.get_preference().background_path)
	_result_panel.visible = false
	_back_button.pressed.connect(_on_back_pressed)
	_fight_button.pressed.connect(_on_fight_pressed)
	_defend_button.pressed.connect(_on_defend_pressed)
	_defend_button.tooltip_text = "Halves incoming damage until your next turn."
	_actions_back_button.pressed.connect(_on_actions_back_pressed)
	_tactics_button.disabled = true
	_tactics_button.tooltip_text = "Not implemented yet -- no auto-battle to configure."
	_forfeit_button.pressed.connect(_on_forfeit_pressed)
	_forfeit_confirm_dialog.confirmed.connect(_on_forfeit_confirmed)
	_apply_formation_button.pressed.connect(_on_apply_formation_pressed)

## opponent_name is online-play only (see game/net/) -- the local 2-window
## flow (battle_setup_screen.gd) has no separate "opponent" identity to show,
## both windows are the same local player, so it leaves this at its default
## and the header stays the plain literal "Opponent".
func setup(controller: BattleController, my_side: String, skill_db: SkillDatabase, opponent_name: String = "") -> void:
	_controller = controller
	_my_side = my_side
	_skill_db = skill_db
	if not opponent_name.is_empty():
		_battlefield_header.text = opponent_name
	_controller.turn_resolved.connect(_on_turn_resolved)
	_controller.battle_ended.connect(_on_battle_ended)
	_sync_staged_formation()
	_append_log("The battle begins!")
	for event in _controller.get_opening_events():
		var line := _describe_event(event)
		if not line.is_empty():
			_append_log(line)
	_advance_to_next_pending_slot()
	_refresh()

## Plain Label, not RichTextLabel -- no bbcode parsing, no append-text/
## visible-characters gotchas to fight, just a string we own and grow
## ourselves. Auto-scrolls to the bottom on each new line.
func _append_log(line: String) -> void:
	_log_label.text += line + "\n"
	await get_tree().process_frame
	_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)

func _opponent_side() -> String:
	return "side_b" if _my_side == "side_a" else "side_a"

func _team_for_side(state: BattleState, side: String) -> Array[MonsterInstance]:
	return state.side_a_team if side == "side_a" else state.side_b_team

func _refresh() -> void:
	var state := _controller.get_state()
	_render_battlefield(state)
	_render_my_party(state)
	_render_command_panel()
	_arena.sync_monsters(state, _my_side)
	_update_turn_counter(state)

## turn_number increments *inside* TurnManager.run_turn() before anything
## else happens, starting at 0 -- binding a label directly to it would show
## "Round 0" while picking your very first move, then "Round 1" while
## picking round 2's actions, one behind what a player expects. +1 always
## reads as "the round currently being decided."
func _update_turn_counter(state: BattleState) -> void:
	_turn_counter_label.text = "Round %d" % (state.turn_number + 1)

## Opponent panel shows one card per unique active opponent monster (a
## multi-slot monster occupies more than one of the 4 raw slot indices, so
## dedupe by instance_id rather than rendering once per index) plus one
## placeholder per still-empty slot. Cards become clickable (as a target
## picker) only while _mode == MODE_TARGETING. The 3D arena (see
## battle_arena_3d.gd) shows the same monsters visually; this panel is what
## stays clickable and keeps showing HP at a glance underneath it.
func _render_battlefield(state: BattleState) -> void:
	for child in _opponent_panel_grid.get_children():
		_opponent_panel_grid.remove_child(child)
		child.queue_free()

	_targeting_label.visible = _mode == MODE_TARGETING
	var seen := {}
	for slot in range(BattleController.ACTIVE_SLOT_COUNT):
		var monster := state.get_monster_at(_opponent_side(), slot)
		if monster != null:
			if seen.has(monster.instance_id):
				continue
			seen[monster.instance_id] = true
		_opponent_panel_grid.add_child(_build_monster_card(monster, false))

## Main Party (your active lineup) and Second Party (bench) render as two
## separate rows -- from the STAGED proposed formation (_staged_active_ids),
## not necessarily what's actually active in the engine yet. Full HP/MP show
## on every card; the currently-commanding monster is highlighted (matched
## by instance_id against whoever the engine says is really at
## _current_slot right now, since a staged-but-unapplied change means the
## card shown there isn't necessarily that monster). Dragging a card
## between the rows stages a proposed change (see _on_party_card_dropped())
## rather than submitting it immediately -- wired only while
## _can_edit_formation() (a drag can't happen mid skill-pick/target-pick,
## nor once this whole side's turn is already locked in for the round).
func _render_my_party(state: BattleState) -> void:
	_clear_flow(_main_party_row)
	_clear_flow(_second_party_row)

	var seen := {}
	for slot in range(BattleController.ACTIVE_SLOT_COUNT):
		var instance_id: int = _staged_active_ids[slot]
		var monster := state.get_monster_by_instance_id(instance_id) if instance_id != -1 else null
		if monster != null:
			if seen.has(monster.instance_id):
				continue
			seen[monster.instance_id] = true
		var card := _build_monster_card(monster, true)
		_highlight_if_commanding(card, monster)
		if _can_edit_formation():
			_wire_active_slot_drag(card, slot, monster)
		_main_party_row.add_child(card)

	for monster in _team_for_side(state, _my_side):
		if _staged_active_ids.has(monster.instance_id):
			continue
		var card := _build_monster_card(monster, true)
		if _can_edit_formation() and not monster.is_fainted():
			_wire_bench_card_drag(card, monster)
		_second_party_row.add_child(card)

	_apply_formation_button.disabled = not _can_edit_formation() or not _has_staged_changes(state)

## Formation edits (drag-and-drop between Main/Second Party, and the Apply
## Formation button) are only meaningful while this side still has at
## least one active slot that hasn't submitted its action yet this round.
## Staging a change is legitimate and expected mid-round -- e.g. you just
## Fight-commanded slot 0 and want to rearrange before commanding slot 1 --
## but once every slot has submitted (_current_slot == -1, the exact same
## moment _render_command_panel() switches to "Waiting for the other
## side...") there is nothing left to apply: submit_swap() would silently
## reject every one of them anyway (BattleController gates per-slot
## submission itself), so leaving the grid draggable was purely
## misleading -- a player could drag a bench monster into an
## already-locked active slot, see the grid visibly "accept" it, and
## reasonably believe they'd switched their monster even though the
## engine's own state never actually changed (this is the real bug behind
## "I can switch my monster even though my turn is over": the UI let you
## keep staging, the engine correctly refused, but nothing told the player
## that refusal happened).
func _can_edit_formation() -> bool:
	return _mode == MODE_MENU and _current_slot != -1

func _clear_flow(container: HFlowContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

## "mine" cards are always disabled (display-only, never clickable via
## pressed -- drag/drop is wired separately), so Button actually renders
## its "disabled" style -- overriding "panel" (not a real Button style
## key) silently did nothing.
func _highlight_if_commanding(card: Button, monster: MonsterInstance) -> void:
	if monster == null:
		return
	var actually_commanding := _controller.get_state().get_monster_at(_my_side, _current_slot)
	if actually_commanding == null or actually_commanding.instance_id != monster.instance_id:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.92, 1, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.24, 0.45, 0.86, 1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.content_margin_left = 10.0
	style.content_margin_top = 6.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("disabled", style)

## A Main Party card (`slot` is always its real anchor slot, even for an
## empty one -- so dropping a bench monster onto an empty active slot
## works too, not just swapping with an existing occupant). `occupant`
## null means nothing to drag FROM here, but it's still a valid drop
## target.
func _wire_active_slot_drag(card: Button, slot: int, occupant: MonsterInstance) -> void:
	card.set_drag_forwarding(
		func(_pos: Vector2) -> Variant: return _make_party_drag_data(card, occupant),
		func(_pos: Vector2, data: Variant) -> bool: return _is_party_drag_data(data),
		func(_pos: Vector2, data: Variant) -> void: _on_party_card_dropped(data["instance_id"], slot, -1)
	)

func _wire_bench_card_drag(card: Button, monster: MonsterInstance) -> void:
	card.set_drag_forwarding(
		func(_pos: Vector2) -> Variant: return _make_party_drag_data(card, monster),
		func(_pos: Vector2, data: Variant) -> bool: return _is_party_drag_data(data),
		func(_pos: Vector2, data: Variant) -> void: _on_party_card_dropped(data["instance_id"], -1, monster.instance_id)
	)

func _make_party_drag_data(card: Control, monster: MonsterInstance) -> Variant:
	if monster == null or monster.is_fainted():
		return null
	var preview := Label.new()
	preview.text = monster.species.display_name
	card.set_drag_preview(preview)
	return {"source": "battle_party_card", "instance_id": monster.instance_id}

func _is_party_drag_data(data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("source") == "battle_party_card"

## Exactly one of target_slot/target_bench_instance_id is meaningful (the
## other is -1) -- which one tells us the intended direction. Both cases
## reduce to the same operation, _stage_drop_at_slot(): dropping onto a
## Main Party slot places the dragged monster there directly; dropping
## onto a Second Party card means "put the bench monster at the dragged
## (active) monster's current staged slot" -- i.e. swap them, the same as
## before, just staged rather than immediate. Dropping a monster onto a
## card of its own kind (active-onto-active, bench-onto-bench) is a no-op.
## Never touches the engine -- see _on_apply_formation_pressed() for that.
##
## Guarded by _can_edit_formation() here too, not just at the drag-wiring
## call sites in _render_my_party() -- closes the narrow race where a drag
## already in flight (started while a slot was still pending) gets
## dropped just after that slot's own action submits mid-drag.
func _on_party_card_dropped(dragged_instance_id: int, target_slot: int, target_bench_instance_id: int) -> void:
	if not _can_edit_formation():
		return
	var state := _controller.get_state()
	var dragged := state.get_monster_by_instance_id(dragged_instance_id)
	if dragged == null or dragged.side != _my_side or dragged.is_fainted():
		return
	var dragged_is_staged_active := _staged_active_ids.has(dragged.instance_id)

	if target_slot != -1:
		if dragged_is_staged_active:
			return
		_stage_drop_at_slot(dragged, target_slot)
	else:
		var target := state.get_monster_by_instance_id(target_bench_instance_id)
		if target == null or not dragged_is_staged_active:
			return
		var dragged_slot := _staged_active_ids.find(dragged.instance_id)
		_stage_drop_at_slot(target, dragged_slot)

	_audio.play_menu_select()
	_render_my_party(state)

## Places `monster` at `slot` (through however many consecutive slots its
## own species.slots needs), evicting -- whole footprint, not just the
## overlapping part -- every distinct monster currently staged anywhere in
## that range first. Mirrors BattleController.submit_swap()'s real
## displacement logic exactly, applied to the plain staged array instead
## of live BattleState, so the staged preview always matches precisely
## what Apply will actually produce.
func _stage_drop_at_slot(monster: MonsterInstance, slot: int) -> void:
	var size := monster.species.slots
	if slot + size > BattleController.ACTIVE_SLOT_COUNT:
		return
	var displaced_ids := {}
	for s in range(slot, slot + size):
		var occupant_id: int = _staged_active_ids[s]
		if occupant_id != -1 and occupant_id != monster.instance_id:
			displaced_ids[occupant_id] = true
	for i in range(_staged_active_ids.size()):
		if displaced_ids.has(_staged_active_ids[i]):
			_staged_active_ids[i] = -1
	for s in range(slot, slot + size):
		_staged_active_ids[s] = monster.instance_id

## Rebuilds _staged_active_ids from whatever's actually active in the
## engine right now -- discards any not-yet-applied staged edits, which is
## exactly right at the start of a new round (see setup()/_on_turn_resolved()),
## since a resolved round's engine state is the only thing that still
## matters going forward.
func _sync_staged_formation() -> void:
	var state := _controller.get_state()
	_staged_active_ids = []
	for slot in range(BattleController.ACTIVE_SLOT_COUNT):
		var monster := state.get_monster_at(_my_side, slot)
		_staged_active_ids.append(monster.instance_id if monster != null else -1)

func _has_staged_changes(state: BattleState) -> bool:
	for slot in range(BattleController.ACTIVE_SLOT_COUNT):
		var current := state.get_monster_at(_my_side, slot)
		var current_id := current.instance_id if current != null else -1
		if _staged_active_ids[slot] != current_id:
			return true
	return false

## Commits the staged formation: for each slot whose staged occupant
## differs from who's really there, calls submit_swap() -- which is itself
## fully size-aware (see wiki/log.md), so this naturally handles a staged
## plan touching several slots at once, re-checking the ACTUAL state before
## each call since an earlier slot's swap can (correctly) already resolve a
## later one as a side effect for a multi-slot monster's footprint.
##
## submit_swap()'s "incoming" monster must be a genuine bench monster --
## it displaces whoever's in its way but has no notion of "relocate an
## already-active monster to a different slot." A staged plan that just
## repositions two already-active monsters relative to each other (no
## actual bench/active change) is skipped rather than passed to
## submit_swap(): calling it with an incoming monster that's still really
## active elsewhere would duplicate that monster across two slots instead
## of moving it, since submit_swap() only ever clears the TARGET range's
## occupant(s), never the incoming monster's own prior slot. Raw slot
## index has no gameplay effect for an already-active monster anyway (see
## wiki/log.md), so there's nothing meaningful to apply for that slot.
func _on_apply_formation_pressed() -> void:
	_audio.play_menu_select()
	var state := _controller.get_state()
	for slot in range(BattleController.ACTIVE_SLOT_COUNT):
		var staged_id: int = _staged_active_ids[slot]
		if staged_id == -1:
			continue
		var current := state.get_monster_at(_my_side, slot)
		if current != null and current.instance_id == staged_id:
			continue
		var staged_monster := state.get_monster_by_instance_id(staged_id)
		if staged_monster == null or state.get_active_monsters(_my_side).has(staged_monster):
			continue
		_controller.submit_swap(_my_side, slot, staged_id)
	_sync_staged_formation()
	_advance_to_next_pending_slot()
	_refresh()

func _build_monster_card(instance: MonsterInstance, mine: bool) -> Button:
	var cell := Button.new()
	var width_scale := instance.species.slots if instance != null else 1
	cell.custom_minimum_size = Vector2(CARD_BASE_WIDTH * width_scale, 100)
	cell.toggle_mode = false
	# Always a bordered "card" (never flat) -- clickability is communicated by
	# disabled state, not by hiding the card's background/border.
	cell.flat = false

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(vbox)

	if instance == null:
		var empty_label := Label.new()
		empty_label.text = "(empty)"
		vbox.add_child(empty_label)
		cell.disabled = true
		return cell

	vbox.add_theme_constant_override("separation", 4)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _art_style.load_texture(instance.species)
	header.add_child(icon)

	# A status badge perches on the portrait's own corner rather than
	# anywhere near the HP bar -- sharing space with the bar (tried twice
	# now) either squeezed its "HP n/max" text or overlapped it once the
	# text got long enough to reach that corner. The portrait has no text
	# of its own to collide with, and a dark circular backdrop behind the
	# icon keeps it readable against any portrait art/color underneath.
	if instance.active_status != null:
		var status_data := instance.active_status.status_data
		var badge_bg := Panel.new()
		badge_bg.custom_minimum_size = Vector2(18, 18)
		badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(0.1, 0.1, 0.12, 0.92)
		badge_style.corner_radius_top_left = 9
		badge_style.corner_radius_top_right = 9
		badge_style.corner_radius_bottom_right = 9
		badge_style.corner_radius_bottom_left = 9
		badge_bg.add_theme_stylebox_override("panel", badge_style)
		icon.add_child(badge_bg)
		badge_bg.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge_bg.position = Vector2(-14, -14)

		var status_icon := TextureRect.new()
		status_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		status_icon.tooltip_text = "%s: %s" % [status_data.display_name, status_data.description]
		if not status_data.icon_path.is_empty():
			status_icon.texture = load(status_data.icon_path)
		badge_bg.add_child(status_icon)
		status_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		status_icon.offset_left = 1
		status_icon.offset_top = 1
		status_icon.offset_right = -1
		status_icon.offset_bottom = -1

	var name_label := Label.new()
	var base_name := "%s [Slot %d]" % [instance.species.display_name, instance.species.slots]
	if instance.is_fainted():
		name_label.text = "%s (fainted)" % base_name
	elif instance.is_defending:
		name_label.text = "%s (Defending)" % base_name
	else:
		name_label.text = base_name
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(name_label)

	# HP bar spans the card's full width below the icon+name row -- the
	# status badge lives on the portrait above instead (see icon.add_child
	# above), so nothing here needs to make room for it.
	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 16)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.max_value = instance.species.base_hp
	hp_bar.value = instance.current_hp
	hp_bar.show_percentage = false
	_style_hp_bar(hp_bar, instance.current_hp, instance.species.base_hp)
	var hp_text := Label.new()
	hp_text.text = "HP %d/%d" % [instance.current_hp, instance.species.base_hp]
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_text.add_theme_font_size_override("font_size", 11)
	hp_text.clip_text = true
	_style_bar_overlay_text(hp_text)
	hp_bar.add_child(hp_text)
	hp_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_child(hp_bar)

	if mine:
		var mp_bar := ProgressBar.new()
		mp_bar.custom_minimum_size = Vector2(0, 16)
		mp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mp_bar.max_value = maxi(1, instance.species.base_mp)
		mp_bar.value = instance.current_mp
		mp_bar.show_percentage = false
		var mp_style := StyleBoxFlat.new()
		mp_style.bg_color = Color(0.32, 0.5, 0.78, 1)
		mp_style.corner_radius_top_left = 3
		mp_style.corner_radius_top_right = 3
		mp_style.corner_radius_bottom_right = 3
		mp_style.corner_radius_bottom_left = 3
		mp_bar.add_theme_stylebox_override("fill", mp_style)
		var mp_text := Label.new()
		mp_text.text = "MP %d/%d" % [instance.current_mp, instance.species.base_mp]
		mp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mp_text.add_theme_font_size_override("font_size", 11)
		_style_bar_overlay_text(mp_text)
		mp_bar.add_child(mp_text)
		mp_text.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.add_child(mp_bar)

	if not mine and _mode == MODE_TARGETING and not instance.is_fainted():
		cell.disabled = false
		cell.pressed.connect(_on_target_picked.bind(instance.instance_id))
	else:
		cell.disabled = true

	return cell

## HP/MP readouts sit on top of a colored fill that varies (green/amber/red
## for HP, blue for MP) -- white text with a dark outline stays legible
## against any of them, unlike the theme's default dark label color which
## would wash out on the darker fills.
func _style_bar_overlay_text(label: Label) -> void:
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("outline_size", 3)

## Green above half HP, amber in the danger zone, red when critical -- a
## quick at-a-glance read without having to parse the numeric label.
func _style_hp_bar(bar: ProgressBar, current: int, max_hp: int) -> void:
	var ratio := float(current) / float(maxi(1, max_hp))
	var color := Color(0.36, 0.72, 0.4, 1) if ratio > 0.5 else (Color(0.85, 0.7, 0.25, 1) if ratio > 0.2 else Color(0.8, 0.28, 0.28, 1))
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	bar.add_theme_stylebox_override("fill", style)

func _advance_to_next_pending_slot() -> void:
	_mode = MODE_MENU
	_pending_skill_id = ""
	var pending: Array = _controller.get_pending_slots(_my_side)
	_current_slot = -1
	for slot in pending:
		if not _controller.is_slot_submitted(_my_side, slot):
			_current_slot = slot
			break

func _render_command_panel() -> void:
	if _controller.is_over():
		_set_command_visibility(false, false, false)
		_waiting_label.visible = false
		return

	if _current_slot == -1:
		_set_command_visibility(false, false, false)
		_waiting_label.visible = true
		_waiting_label.text = "Waiting for the other side..."
		return

	_waiting_label.visible = false
	var commanding := _controller.get_state().get_monster_at(_my_side, _current_slot)
	_current_slot_label.text = "Commanding: %s" % (commanding.species.display_name if commanding != null else "???")

	match _mode:
		MODE_SKILLS:
			_rebuild_skill_buttons()
			_set_command_visibility(false, false, true)
		MODE_TARGETING:
			_set_command_visibility(false, false, false)
		_:
			_set_command_visibility(true, true, false)

## Forfeit is a top-level choice, not a per-monster command -- it's shown
## exactly when Fight/Tactics are (the main command screen), and hidden the
## moment you drill into either's sub-flow (Fight's skill list, a target
## picker), same as they are. `fight` doubles as that "are we on the main
## command screen" flag since every call site already keeps fight/tactics
## in lockstep with each other. Formation changes no longer go through a
## separate "Orders" sub-menu -- see _wire_active_slot_drag()/
## _wire_bench_card_drag() -- so there's no bench-list visibility to track
## here anymore.
func _set_command_visibility(fight: bool, tactics: bool, actions: bool) -> void:
	_fight_button.visible = fight
	_defend_button.visible = fight
	_forfeit_button.visible = fight
	_tactics_button.visible = tactics
	_actions_scroll.visible = actions

func _rebuild_skill_buttons() -> void:
	for child in _actions_box.get_children():
		if child == _actions_back_button:
			continue
		_actions_box.remove_child(child)
		child.queue_free()

	var actor := _controller.get_state().get_monster_at(_my_side, _current_slot)
	if actor == null:
		return
	for skill in actor.learned_skills:
		var button := Button.new()
		button.text = "%s (%d MP)" % [skill.display_name, skill.mp_cost]
		button.disabled = actor.current_mp < skill.mp_cost
		button.pressed.connect(_on_skill_pressed.bind(skill.id))
		if not skill.description.is_empty():
			button.tooltip_text = skill.description
		_actions_box.add_child(button)

func _on_fight_pressed() -> void:
	_audio.play_menu_select()
	_mode = MODE_SKILLS
	_render_command_panel()

func _on_actions_back_pressed() -> void:
	_audio.play_menu_select()
	_mode = MODE_MENU
	_render_command_panel()

## Defend always succeeds -- no chance roll, just queues the
## action for this slot.
func _on_defend_pressed() -> void:
	_audio.play_menu_select()
	_controller.submit_defend(_my_side, _current_slot)
	_advance_to_next_pending_slot()
	_refresh()

func _on_forfeit_pressed() -> void:
	_audio.play_menu_select()
	_forfeit_confirm_dialog.popup_centered()

## Ends the battle immediately, crediting the opponent with the win.
## BattleController.forfeit() reuses the same action_submitted plumbing
## submit_fight/submit_swap already use, so online play forwards this to
## the opponent for free -- no separate network wiring needed here.
func _on_forfeit_confirmed() -> void:
	_controller.forfeit(_my_side)

func _on_skill_pressed(skill_id: String) -> void:
	var skill := _skill_db.get_skill(skill_id)
	if skill == null:
		return
	_audio.play_menu_select()
	if skill.target_type == SkillData.TargetType.SELF:
		_controller.submit_fight(_my_side, _current_slot, skill_id, -1)
		_advance_to_next_pending_slot()
		_refresh()
		return

	_pending_skill_id = skill_id
	_mode = MODE_TARGETING
	_refresh()

func _on_target_picked(target_instance_id: int) -> void:
	_audio.play_menu_select()
	_controller.submit_fight(_my_side, _current_slot, _pending_skill_id, target_instance_id)
	_advance_to_next_pending_slot()
	_refresh()

## A coroutine: awaits each event's animation before moving to the next one,
## so a round with several attacks plays them out one at a time instead of
## all at once. The command panel is hidden for the whole sequence -- since
## _refresh() (which restores it to whatever the *new* round actually needs)
## only runs at the very end, leaving the old buttons up while animations
## play would let the player click something stale mid-sequence.
func _on_turn_resolved(events: Array[BattleEvent]) -> void:
	_sync_staged_formation()
	_advance_to_next_pending_slot()
	_set_command_visibility(false, false, false)
	_waiting_label.visible = true
	_waiting_label.text = "Resolving turn..."
	for event in events:
		var line := _describe_event(event)
		if not line.is_empty():
			_append_log(line)
		await _animate_event(event)
	# _refresh() (which re-syncs the arena's sprites, reassigning them for
	# anyone fainted-and-backfilled this round, and restores the command
	# panel to whatever the new round actually needs) must stay LAST --
	# animating or narrating after it ran could target a sprite that's
	# already been repurposed for a replacement monster.
	_refresh()

## Every attack visibly steps its actor toward the target and back
## unconditionally (hit, miss, fizzle, any target type) -- matches "every
## time a monster attacks," no "is this offensive" classification invented.
## The one exception is a status-prevented action (asleep, paralyzed,
## silenced, ...): the monster never actually attempted the move, so it
## doesn't lunge or play the attack sound, just sits out the turn.
## Only the attacker moves; a damaged target doesn't flinch/shake, just
## plays a sound. Awaits the full attack animation so the caller's per-event
## loop pauses here before starting the next event's.
func _animate_event(event: BattleEvent) -> void:
	if event is SkillUsedEvent and event.prevented_by_status.is_empty() and event.prevented_by_trait.is_empty():
		_audio.play_attack()
		await _arena.animate_attack(event.actor_instance_id, event.target_instance_id)
		if event.missed:
			_arena.show_floating_text(event.target_instance_id, "Miss!", BattleArena3D.MISS_TEXT_COLOR)
	elif event is DamageAppliedEvent:
		if event.was_negated:
			_arena.show_floating_text(event.target_instance_id, "Miss!", BattleArena3D.MISS_TEXT_COLOR)
		else:
			_audio.play_hit()
			if event.is_critical:
				_arena.show_floating_text(event.target_instance_id, "Critical!\n%d" % event.amount, BattleArena3D.CRITICAL_TEXT_COLOR)
			else:
				_arena.show_floating_text(event.target_instance_id, str(event.amount), BattleArena3D.DAMAGE_TEXT_COLOR)
	elif event is StatusTickEvent:
		if event.damage > 0:
			_arena.show_floating_text(event.target_instance_id, str(event.damage), BattleArena3D.STATUS_DAMAGE_TEXT_COLOR)
	elif event is MonsterFaintedEvent:
		_audio.play_faint()
		await _arena.animate_faint(event.instance_id)

func _on_battle_ended(winner_side: String) -> void:
	_result_panel.visible = true
	_result_label.text = "You Win!" if winner_side == _my_side else "You Lose!"

## Online play only (see game/net/) -- reuses the same "stop taking input,
## show a message, offer a way out" panel _on_battle_ended already shows,
## rather than building separate UI for a mid-battle disconnect.
func show_disconnect_message(text: String) -> void:
	_result_panel.visible = true
	_result_label.text = text

func _on_back_pressed() -> void:
	close_requested.emit()

func _describe_event(event: BattleEvent) -> String:
	if event is SkillUsedEvent:
		var e: SkillUsedEvent = event
		var actor := _find_instance(e.actor_instance_id)
		var actor_name := actor.species.display_name if actor != null else "???"
		var skill := _skill_db.get_skill(e.skill_id)
		var skill_name := skill.display_name if skill != null else e.skill_id
		if not e.prevented_by_status.is_empty():
			var status := _skill_db.get_status(e.prevented_by_status)
			var status_name := status.display_name if status != null else e.prevented_by_status.capitalize()
			if status != null and not status.blocked_skill_category.is_empty():
				return "%s can't use %s while %s!" % [actor_name, skill_name, status_name]
			return "%s can't move! (%s)" % [actor_name, status_name]
		if not e.prevented_by_trait.is_empty():
			return "%s is too %s to move!" % [actor_name, e.prevented_by_trait.capitalize()]
		if e.missed:
			return "%s used %s but missed!" % [actor_name, skill_name]
		if e.fizzled:
			return "%s tried to use %s but it fizzled!" % [actor_name, skill_name]
		return "%s used %s!" % [actor_name, skill_name]
	if event is DamageAppliedEvent:
		var e2: DamageAppliedEvent = event
		var target := _find_instance(e2.target_instance_id)
		var target_name := target.species.display_name if target != null else "???"
		if e2.was_negated:
			return "%s dodged the attack!" % target_name
		if e2.is_critical:
			return "Critical hit! %s took %d damage! (%d HP left)" % [target_name, e2.amount, e2.resulting_hp]
		return "%s took %d damage! (%d HP left)" % [target_name, e2.amount, e2.resulting_hp]
	if event is HealingAppliedEvent:
		var e3: HealingAppliedEvent = event
		var target2 := _find_instance(e3.target_instance_id)
		var target_name2 := target2.species.display_name if target2 != null else "???"
		return "%s recovered %d HP! (%d HP left)" % [target_name2, e3.amount, e3.resulting_hp]
	if event is StatusAppliedEvent:
		var e4: StatusAppliedEvent = event
		var target3 := _find_instance(e4.target_instance_id)
		var target_name3 := target3.species.display_name if target3 != null else "???"
		return "%s is afflicted with %s!" % [target_name3, e4.status_id.capitalize()]
	if event is MonsterFaintedEvent:
		var e5: MonsterFaintedEvent = event
		var m := _find_instance(e5.instance_id)
		var m_name := m.species.display_name if m != null else "???"
		return "%s fainted!" % m_name
	if event is MonsterEnteredEvent:
		var e6: MonsterEnteredEvent = event
		var m2 := _find_instance(e6.instance_id)
		var m_name2 := m2.species.display_name if m2 != null else e6.species_id
		return "%s enters the battle!" % m_name2
	if event is StatusTickEvent:
		var e7: StatusTickEvent = event
		var target4 := _find_instance(e7.target_instance_id)
		var target_name4 := target4.species.display_name if target4 != null else "???"
		var status_name := e7.status_id.capitalize()
		var lines: Array[String] = []
		if e7.damage > 0:
			lines.append("%s is hurt by %s! (%d HP left)" % [target_name4, status_name, e7.resulting_hp])
		if e7.expired:
			lines.append("%s's %s wore off." % [target_name4, status_name])
		return "\n".join(lines)
	if event is StatChangedEvent:
		var e8: StatChangedEvent = event
		var target5 := _find_instance(e8.target_instance_id)
		var target_name5 := target5.species.display_name if target5 != null else "???"
		var stat_name := e8.stat_name.capitalize()
		if e8.delta_applied == 0:
			return "%s's %s won't go any further!" % [target_name5, stat_name]
		var direction := "rose" if e8.delta_applied > 0 else "fell"
		var qualifier := " sharply" if absi(e8.delta_applied) >= 2 else ""
		return "%s's %s %s%s!" % [target_name5, stat_name, direction, qualifier]
	if event is TurnStartedEvent:
		return "\nRound %d" % event.turn_number
	if event is DefendEvent:
		var e11: DefendEvent = event
		var defender := _find_instance(e11.actor_instance_id)
		var defender_name := defender.species.display_name if defender != null else "???"
		return "%s is defending!" % defender_name
	if event is MpDrainEvent:
		var e12: MpDrainEvent = event
		var drainer := _find_instance(e12.source_instance_id)
		var drainer_name := drainer.species.display_name if drainer != null else "???"
		var drained_from := _find_instance(e12.target_instance_id)
		var drained_from_name := drained_from.species.display_name if drained_from != null else "???"
		return "%s drains %d MP from %s!" % [drainer_name, e12.amount, drained_from_name]
	if event is ReviveEvent:
		var e13: ReviveEvent = event
		var revived := _find_instance(e13.instance_id)
		var revived_name := revived.species.display_name if revived != null else "???"
		return "%s came back from the brink! (%d HP)" % [revived_name, e13.resulting_hp]
	if event is BattleEndedEvent:
		var e9: BattleEndedEvent = event
		return "You win the battle!" if e9.winner_side == _my_side else "You lose the battle!"
	return ""

func _find_instance(instance_id: int) -> MonsterInstance:
	return _controller.get_state().get_monster_by_instance_id(instance_id)
