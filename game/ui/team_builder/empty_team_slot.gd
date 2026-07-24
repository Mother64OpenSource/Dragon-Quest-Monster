class_name EmptyTeamSlot
extends PanelContainer

## The unused remainder of a party row's slot-point budget (see
## TeamFormationLayout) -- sized to however many slot-points are actually
## left (space_units * TeamMemberRow.SPACE_UNIT_WIDTH), not a fixed cell
## width, since the remainder shrinks as the party fills up. A party never
## has "holes" between real members -- real members always occupy the
## front, so dropping a dragged TeamMemberRow onto this remainder always
## means the same thing regardless of exactly where in it you drop:
## "move this member to the end of the list."

signal member_dropped(from_index: int)

func configure(space_units: int) -> void:
	custom_minimum_size = Vector2(TeamMemberRow.SPACE_UNIT_WIDTH * space_units, TeamMemberRow.CELL_HEIGHT)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("source") == "team_member_row"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	member_dropped.emit(data["from_index"])
