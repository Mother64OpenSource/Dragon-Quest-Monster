class_name TensionGainOnStatusTraitEffect
extends TraitEffect

## Stalwart Spirit: "When struck by stasis status, you will increase your
## Tension by 2 levels." No "stasis" status exists among this engine's 9
## real ones -- interpreted as immobilize (a stun/miss-a-turn status), the
## same analogy Inaction Ward/Crafty Inactivist already use for "Snooze."
## Reuses the on_status_afflicted hook Tit for Tat already established
## (fires on the recipient right after StatusEffect.apply() succeeds).

@export var status_ids: Array[String] = ["immobilize"]
@export var levels: int = 2

func on_status_afflicted(_ctx: BattleContext, owner: MonsterInstance, _inflicter: MonsterInstance, status_data: StatusData) -> void:
	if not status_ids.has(status_data.id):
		return
	owner.tension_level = mini(4, owner.tension_level + levels)
