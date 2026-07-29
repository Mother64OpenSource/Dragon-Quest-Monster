class_name DefendingChampionEffect
extends SkillEffect

## "Reduce damage by 1/10 during 1 battle. Can only use once." Unlike
## Defend/Taunt/Counter-stance/Deep Breath/Mist Me, this is NOT a one-turn
## effect -- ActionExecutor.execute() deliberately never resets it, so it
## lasts the rest of the battle once cast (see
## MonsterInstance.defending_champion_active's own doc comment). Casting
## it again while already active is a harmless no-op, which is a fine
## reading of "can only use once" given there's no real mechanical
## difference between casting it twice and once.
func apply(_ctx: BattleContext, user: MonsterInstance, _target: MonsterInstance) -> void:
	user.defending_champion_active = true
