extends SceneTree

## Deployment entry point for the always-on WebSocket relay server (see
## game/net/network_manager.gd's RELAY_SERVER mode and
## game/net/relay_server_logic.gd). Deliberately doesn't load the normal
## game (team builder screen, monster/skill/trait databases, etc.) -- the
## relay process should stay lean, since it never simulates a battle, only
## forwards messages between whichever two clients a room code pairs up.
##
## The project's "Network" autoload (network_manager.gd) always loads
## regardless of which script/scene is used to enter the SceneTree -- its
## own _ready() checks for --relay-server on the command line and does the
## actual work of starting the WebSocket server; this script exists only to
## be *a* valid entry point that never touches the main scene, and to keep
## the process running instead of immediately quitting.
##
## Run as (the `--` separates Godot's own flags from this project's):
##   godot --headless --path game --script res://net/run_relay_server.gd -- --relay-server --relay-port=27931
func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--relay-server"):
		push_error("run_relay_server.gd requires --relay-server after -- on the command line.")
		quit(1)
