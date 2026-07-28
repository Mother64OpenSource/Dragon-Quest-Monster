class_name MainShell
extends Control

## Top-level app shell: a Pokemon-Showdown-style tab strip (see wiki/log.md)
## instead of change_scene_to_file for local battles -- "Home" (the team
## builder) is a permanent, unclosable tab; starting a local battle opens a
## second tab that keeps running even while you're looking at Home, exactly
## like Showdown's battle rooms alongside its own Home tab. Switching tabs
## only toggles Control.visible on each page -- Godot doesn't stop
## processing a hidden node, so a battle left in a background tab keeps
## ticking (animations, network polling, etc.) exactly like Showdown's do.
##
## Online battles (see game/ui/online/) still use the older
## change_scene_to_file flow for now -- deliberately out of scope for this
## pass, since giving them a tab too would also need deciding what a closed
## tab does to a live network connection. This shell is still the one true
## res://ui/team_builder root scene now, though, so network_setup_screen.gd's
## own "back to team builder" targets this scene instead of the bare
## TeamBuilderScreen, or losing the tab bar the moment you left Home once
## would be a real, surprising regression.

const TeamBuilderScreenScene := preload("res://ui/team_builder/team_builder_screen.tscn")

## Parallel to the TabBar's own tabs (index-for-index) -- TabBar only owns
## the header strip, not any content, so this project's own page Controls
## are tracked here instead.
var _pages: Array[Control] = []

@onready var _tab_bar: TabBar = $VBoxContainer/TabBarPanel/TabBar
@onready var _pages_container: Control = $VBoxContainer/PagesContainer

func _ready() -> void:
	# TabBar's close-button policy is all-or-nothing across every tab (no
	# per-tab override exists) -- shown on every tab including Home, but
	# _on_tab_close_pressed() simply ignores index 0, so Home's own close
	# button is inert rather than hidden. A harmless cosmetic gap from
	# Showdown's own look (Home has no visible close X there at all).
	_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ALWAYS
	_tab_bar.tab_changed.connect(_on_tab_changed)
	_tab_bar.tab_close_pressed.connect(_on_tab_close_pressed)
	# TEMPORARY diagnostic -- logs every raw mouse click MainShell itself
	# sees (via _input, unconditionally, before any Control gets first
	# refusal) alongside every click the TabBar's OWN gui_input actually
	# receives, so a report of "clicking the tab bar does nothing" can be
	# pinned to an exact cause (the click never arrives at all vs. arrives
	# but TabBar doesn't react vs. TabBar reacts but visibility doesn't
	# follow) instead of guessed at again. Remove once root-caused.
	_tab_bar.gui_input.connect(_on_tab_bar_gui_input)

	var home: TeamBuilderScreen = TeamBuilderScreenScene.instantiate()
	_add_page("Home", home)
	home.battle_launched.connect(_on_home_battle_launched)

## TEMPORARY diagnostic -- see _ready(). Fires for EVERY raw input event
## reaching the SceneTree, regardless of which Control (if any) ends up
## handling it, so a click that never shows up here at all means it never
## reached Godot's input system in the first place (a real OS/window-level
## issue), while a click that shows up here but not in
## _on_tab_bar_gui_input below means Godot saw it but something else
## claimed it before the TabBar did.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("[DIAG] MainShell._input saw a mouse press at ", event.global_position, " button_index=", event.button_index, " current_tab=", _tab_bar.current_tab)

## TEMPORARY diagnostic -- see _ready(). Fires only if the TabBar Control
## itself actually received the click as its own GUI input.
func _on_tab_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("[DIAG] TabBar.gui_input received a mouse press at ", event.global_position, " current_tab (before)=", _tab_bar.current_tab)

## Guaranteed keyboard fallback for switching tabs, independent of whatever
## might be preventing a real click from reaching the TabBar Control (still
## being tracked down -- see the diagnostic prints above). Ctrl+Tab / Ctrl+
## Shift+Tab cycle forward/backward through whatever tabs currently exist,
## same convention as browsers and most tabbed editors, and go through
## _select_tab() directly -- the exact same code path a real tab click
## would have used, just triggered a different way, so it's a complete
## workaround rather than a partial one.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and event.ctrl_pressed and event.keycode == KEY_TAB):
		return
	if _pages.is_empty():
		return
	var direction := -1 if event.shift_pressed else 1
	var next_index := (_tab_bar.current_tab + direction + _pages.size()) % _pages.size()
	_select_tab(next_index)
	get_viewport().set_input_as_handled()

func _add_page(title: String, page: Control) -> void:
	_pages_container.add_child(page)
	_pages.append(page)
	_tab_bar.add_tab(title)
	_select_tab(_pages.size() - 1)

func _select_tab(index: int) -> void:
	_tab_bar.current_tab = index
	_update_page_visibility()

func _on_tab_changed(_index: int) -> void:
	_update_page_visibility()

func _update_page_visibility() -> void:
	for i in range(_pages.size()):
		_pages[i].visible = (i == _tab_bar.current_tab)

func _on_tab_close_pressed(index: int) -> void:
	if index == 0:
		return
	_close_tab_at(index)

func _close_tab_at(index: int) -> void:
	var page := _pages[index]
	_pages.remove_at(index)
	_tab_bar.remove_tab(index)
	page.queue_free()
	_select_tab(0)

## BattleSideView is handed over already fully set up (see
## BattleSetupScreen._on_start_pressed) -- this just gives it a tab and
## switches to it, same as any other page. Switching back to Home mid-
## battle needs no signal from the view itself -- clicking the Home tab in
## the strip already does that non-destructively (just toggles which page
## is visible, doesn't touch this one), exactly like a Showdown battle
## room keeps running while you're looking at Home. close_requested (the
## result panel's own Back button, once the battle is actually over) is
## the one signal that really does close the tab.
func _on_home_battle_launched(view: Control, tab_title: String) -> void:
	_add_page(tab_title, view)
	if view.has_signal("close_requested"):
		view.close_requested.connect(_on_battle_tab_close_requested.bind(view))

func _on_battle_tab_close_requested(view: Control) -> void:
	var index := _pages.find(view)
	if index != -1:
		_close_tab_at(index)
