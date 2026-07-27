class_name PlayerProfile
extends Resource

## The local player's own identity: a display name and an avatar (any
## existing monster species' sprite, not separate art). Exactly one of
## these exists per install -- see PlayerProfileManager -- so unlike
## SavedTeam there's no id/slug, nothing to key a list by.

@export var player_name: String = ""
@export var avatar_species_id: String = ""
