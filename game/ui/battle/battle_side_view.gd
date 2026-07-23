class_name BattleSideView
extends Control

## Per-window battle UI for one side. Two of these exist per battle (one per
## OS window), both pointed at the same BattleController -- there is no
## networking, they're just two Control trees sharing one process's memory.
##
## Layout: a "battlefield" facing the opponent's up to 4 active monsters, a
## row of your own active monsters, and a command panel that cycles through
## each of your not-yet-submitted active slots in turn. Cards render once
## per unique active monster (not once per raw slot index) in an
## HFlowContainer, wide in proportion to that monster's own species.slots
## (1-4) -- a 2-slot monster's card is twice as wide as a 1-slot one, a
## 4-slot monster's card fills a whole row alone. A rigid fixed-column grid
## can't cleanly represent an odd slot count like 3-of-4 as a rectangle, so
## a flow layout that just wraps naturally was simpler and more honest than
## fighting grid geometry. "Fight" drills into a skill list; picking a
## single-enemy skill switches the battlefield into target-picking mode
## (only living enemy cards are clickable). "Orders" swaps a living bench
## monster into the current slot (consumes that slot's turn for the round).
## "Tactics" remains an inert stub. Built from this project's own
## default-theme controls and monster icons, not a copy of any specific
## game's actual art/assets.

const CARD_BASE_WIDTH := 140

const MODE_MENU := "menu"
const MODE_SKILLS := "skills"
const MODE_TARGETING := "targeting"
const MODE_ORDERS := "orders"

var _controller: BattleController
var _my_side: String
var _skill_db: SkillDatabase
var _current_slot: int = -1
var _mode: String = MODE_MENU
var _pending_skill_id: String = ""

@onready var _battlefield_grid: HFlowContainer = $VBoxContainer/Battlefield/MarginContainer/VBox/BattlefieldGrid
@onready var _current_slot_label: Label = $VBoxContainer/BottomPanel/CommandPanel/CommandPanelVBox/CurrentSlotLabel
@onready var _fight_button: Button = $VBoxContainer/BottomPanel/CommandPanel/CommandPanelVBox/FightButton
@onready var _orders_button: Button = $VBoxContainer/BottomPanel/CommandPanel/CommandPanelVBox/OrdersButton
@onready var _tactics_button: Button = $VBoxContainer/BottomPanel/CommandPanel/CommandPanelVBox/TacticsButton
@onready var _actions_scroll: ScrollContainer = $VBoxContainer/BottomPanel/CommandPanel/CommandPanelVBox/ActionsScroll
@onready var _actions_box: VBoxContainer = $VBoxContainer/BottomPanel/CommandPanel/CommandPanelVBox/ActionsScroll/ActionsBox
@onready var _actions_back_button: Button = $VBoxContainer/BottomPanel/CommandPanel/CommandPanelVBox/ActionsScroll/ActionsBox/BackButton
@onready var _my_party_grid: HFlowContainer = $VBoxContainer/BottomPanel/MyPartyPanel/MyPartyVBox/MyPartyGrid
@onready var _waiting_label: Label = $VBoxContainer/WaitingLabel
@onready var _targeting_label: Label = $VBoxContainer/Battlefield/MarginContainer/VBox/TargetingLabel
@onready var _log_label: RichTextLabel = $VBoxContainer/LogScroll/LogLabel
@onready var _result_panel: PanelContainer = $VBoxContainer/ResultPanel
@onready var _result_label: Label = $VBoxContainer/ResultPanel/VBoxContainer/ResultLabel
@onready var _back_button: Button = $VBoxContainer/ResultPanel/VBoxContainer/BackButton

func _ready() -> void:
	_result_panel.visible = false
	_back_button.pressed.connect(_on_back_pressed)
	_fight_button.pressed.connect(_on_fight_pressed)
	_orders_button.pressed.connect(_on_orders_pressed)
	_actions_back_button.pressed.connect(_on_actions_back_pressed)
	_tactics_button.disabled = true
	_tactics_button.tooltip_text = "Not implemented yet -- no auto-battle to configure."

func setup(controller: BattleController, my_side: String, skill_db: SkillDatabase) -> void:
	_controller = controller
	_my_side = my_side
	_skill_db = skill_db
	_controller.turn_resolved.connect(_on_turn_resolved)
	_controller.battle_ended.connect(_on_battle_ended)
	_advance_to_next_pending_slot()
	_refresh()

func _opponent_side() -> String:
	return "side_b" if _my_side == "side_a" else "side_a"

func _team_for_side(state: BattleState, side: String) -> Array[MonsterInstance]:
	return state.side_a_team if side == "side_a" else state.side_b_team

func _refresh() -> void:
	var state := _controller.get_state()
	_render_battlefield(state)
	_render_my_party(state)
	_render_command_panel()

## Battlefield shows one card per unique active opponent monster (a
## multi-slot monster occupies more than one of the 4 raw slot indices, so
## dedupe by instance_id rather than rendering once per index) plus one
## placeholder per still-empty slot. Cards become clickable (as a target
## picker) only while _mode == MODE_TARGETING.
func _render_battlefield(state: BattleState) -> void:
	for child in _battlefield_grid.get_children():
		_battlefield_grid.remove_child(child)
		child.queue_free()

	_targeting_label.visible = _mode == MODE_TARGETING
	var seen := {}
	for slot in range(BattleController.ACTIVE_SLOT_COUNT):
		var monster := state.get_monster_at(_opponent_side(), slot)
		if monster != null:
			if seen.has(monster.instance_id):
				continue
			seen[monster.instance_id] = true
		_battlefield_grid.add_child(_build_monster_card(monster, false))

## mine parties show full HP/MP; the currently-selected monster is
## highlighted (by its anchor slot, MonsterInstance.slot).
func _render_my_party(state: BattleState) -> void:
	for child in _my_party_grid.get_children():
		_my_party_grid.remove_child(child)
		child.queue_free()

	var seen := {}
	for slot in range(BattleController.ACTIVE_SLOT_COUNT):
		var monster := state.get_monster_at(_my_side, slot)
		if monster != null:
			if seen.has(monster.instance_id):
				continue
			seen[monster.instance_id] = true
		var card := _build_monster_card(monster, true)
		if monster != null and monster.slot == _current_slot:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.25, 0.4, 0.25)
			card.add_theme_stylebox_override("panel", style)
		_my_party_grid.add_child(card)

func _build_monster_card(instance: MonsterInstance, mine: bool) -> Button:
	var cell := Button.new()
	var width_scale := instance.species.slots if instance != null else 1
	cell.custom_minimum_size = Vector2(CARD_BASE_WIDTH * width_scale, 100)
	cell.toggle_mode = false
	cell.flat = not (mine == false and _mode == MODE_TARGETING)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(vbox)

	if instance == null:
		var empty_label := Label.new()
		empty_label.text = "(empty)"
		vbox.add_child(empty_label)
		cell.disabled = true
		return cell

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not instance.species.sprite_path.is_empty():
		icon.texture = load(instance.species.sprite_path)
	vbox.add_child(icon)

	var name_label := Label.new()
	var base_name := "%s [Slot %d]" % [instance.species.display_name, instance.species.slots]
	name_label.text = base_name if not instance.is_fainted() else "%s (fainted)" % base_name
	name_label.clip_text = true
	vbox.add_child(name_label)

	var hp_row := HBoxContainer.new()
	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(60, 10)
	hp_bar.max_value = instance.species.base_hp
	hp_bar.value = instance.current_hp
	hp_bar.show_percentage = false
	_style_hp_bar(hp_bar, instance.current_hp, instance.species.base_hp)
	hp_row.add_child(hp_bar)
	var hp_label := Label.new()
	hp_label.text = "HP %d/%d" % [instance.current_hp, instance.species.base_hp]
	hp_row.add_child(hp_label)
	vbox.add_child(hp_row)

	if mine:
		var mp_row := HBoxContainer.new()
		var mp_bar := ProgressBar.new()
		mp_bar.custom_minimum_size = Vector2(60, 10)
		mp_bar.max_value = maxi(1, instance.species.base_mp)
		mp_bar.value = instance.current_mp
		mp_bar.show_percentage = false
		mp_row.add_child(mp_bar)
		var mp_label := Label.new()
		mp_label.text = "MP %d/%d" % [instance.current_mp, instance.species.base_mp]
		mp_row.add_child(mp_label)
		vbox.add_child(mp_row)

	if not mine and _mode == MODE_TARGETING and not instance.is_fainted():
		cell.disabled = false
		cell.pressed.connect(_on_target_picked.bind(instance.instance_id))
	else:
		cell.disabled = true

	return cell

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
		_set_command_visibility(false, false, false, false)
		_waiting_label.visible = false
		return

	if _current_slot == -1:
		_set_command_visibility(false, false, false, false)
		_waiting_label.visible = true
		_waiting_label.text = "Waiting for the other side..."
		return

	_waiting_label.visible = false
	var commanding := _controller.get_state().get_monster_at(_my_side, _current_slot)
	_current_slot_label.text = "Commanding: %s" % (commanding.species.display_name if commanding != null else "???")

	match _mode:
		MODE_SKILLS:
			_rebuild_skill_buttons()
			_set_command_visibility(false, false, false, true)
		MODE_TARGETING:
			_set_command_visibility(false, false, false, false)
		_:
			var actor := _controller.get_state().get_monster_at(_my_side, _current_slot)
			_orders_button.disabled = _controller.get_living_bench(_my_side).is_empty()
			_orders_button.tooltip_text = "" if not _orders_button.disabled else "No living bench monster to swap in."
			_set_command_visibility(true, true, true, false)

func _set_command_visibility(fight: bool, orders: bool, tactics: bool, actions: bool) -> void:
	_fight_button.visible = fight
	_orders_button.visible = orders
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
		_actions_box.add_child(button)

func _rebuild_bench_buttons() -> void:
	for child in _actions_box.get_children():
		if child == _actions_back_button:
			continue
		_actions_box.remove_child(child)
		child.queue_free()

	for bench_monster in _controller.get_living_bench(_my_side):
		var button := Button.new()
		button.text = "Swap in: %s" % bench_monster.species.display_name
		button.pressed.connect(_on_bench_picked.bind(bench_monster.instance_id))
		_actions_box.add_child(button)

func _on_fight_pressed() -> void:
	_mode = MODE_SKILLS
	_render_command_panel()

func _on_orders_pressed() -> void:
	_mode = MODE_ORDERS
	_rebuild_bench_buttons()
	_set_command_visibility(false, false, false, true)

func _on_actions_back_pressed() -> void:
	_mode = MODE_MENU
	_render_command_panel()

func _on_skill_pressed(skill_id: String) -> void:
	var skill := _skill_db.get_skill(skill_id)
	if skill == null:
		return
	if skill.target_type == SkillData.TargetType.SELF:
		_controller.submit_fight(_my_side, _current_slot, skill_id, -1)
		_advance_to_next_pending_slot()
		_refresh()
		return

	_pending_skill_id = skill_id
	_mode = MODE_TARGETING
	_refresh()

func _on_target_picked(target_instance_id: int) -> void:
	_controller.submit_fight(_my_side, _current_slot, _pending_skill_id, target_instance_id)
	_advance_to_next_pending_slot()
	_refresh()

func _on_bench_picked(bench_instance_id: int) -> void:
	_controller.submit_swap(_my_side, _current_slot, bench_instance_id)
	_advance_to_next_pending_slot()
	_refresh()

func _on_turn_resolved(events: Array[BattleEvent]) -> void:
	_advance_to_next_pending_slot()
	for event in events:
		var line := _describe_event(event)
		if not line.is_empty():
			_log_label.append_text(line + "\n")
	_refresh()

func _on_battle_ended(winner_side: String) -> void:
	_result_panel.visible = true
	_result_label.text = "You Win!" if winner_side == _my_side else "You Lose!"

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/team_builder/team_builder_screen.tscn")

func _describe_event(event: BattleEvent) -> String:
	if event is SkillUsedEvent:
		var e: SkillUsedEvent = event
		var actor := _find_instance(e.actor_instance_id)
		var actor_name := actor.species.display_name if actor != null else "???"
		var skill := _skill_db.get_skill(e.skill_id)
		var skill_name := skill.display_name if skill != null else e.skill_id
		if e.missed:
			return "%s used %s but missed!" % [actor_name, skill_name]
		if e.fizzled:
			return "%s tried to use %s but it fizzled!" % [actor_name, skill_name]
		return "%s used %s!" % [actor_name, skill_name]
	if event is DamageAppliedEvent:
		var e2: DamageAppliedEvent = event
		var target := _find_instance(e2.target_instance_id)
		var target_name := target.species.display_name if target != null else "???"
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
		return "%s is afflicted with %s!" % [target_name3, e4.status_id]
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
	return ""

func _find_instance(instance_id: int) -> MonsterInstance:
	return _controller.get_state().get_monster_by_instance_id(instance_id)
