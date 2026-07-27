class_name BackgroundPreference
extends Resource

## The player's chosen team-builder background image/GIF -- a single
## user://-local file path, or empty for "no custom background chosen yet,
## show the default." See BackgroundPreferenceManager for how the actual
## file gets there (always copied into user://backgrounds/, never
## referenced at its original external location).

@export var background_path: String = ""
