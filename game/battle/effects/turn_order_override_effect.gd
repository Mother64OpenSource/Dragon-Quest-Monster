class_name TurnOrderOverrideEffect
extends SkillEffect

## Shuffle ("all monsters attack in random order, regardless of AGI or
## traits") and Unnatural Order ("causes monsters with the lowest AGI to
## move first") both override how the NEXT round's action order gets
## built, rather than affecting anything about the current cast itself.
## Just sets the matching BattleState flag -- see its own doc comment for
## why this is next-round, not retroactive.

enum Mode { SHUFFLE, REVERSE }

@export var mode: Mode = Mode.SHUFFLE

func apply(ctx: BattleContext, _user: MonsterInstance, _target: MonsterInstance) -> void:
	if mode == Mode.SHUFFLE:
		ctx.state.shuffle_next_round = true
	else:
		ctx.state.reverse_next_round = true
