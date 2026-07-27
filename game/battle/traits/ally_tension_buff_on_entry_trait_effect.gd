class_name AllyTensionBuffOnEntryTraitEffect
extends TraitEffect

## Rabble Rouser: "an ally's tension may rise at the start of a battle" --
## singular wording (unlike the flat party-wide Sudden Buff/Oomph), so this
## picks ONE random currently-active ally (owner included) rather than
## buffing everyone. No event exists for a tension change anywhere in this
## project (see ChanceBasedTensionGainTraitEffect) -- silent state mutation
## is the established convention, not an oversight here.

@export var chance: float = 0.5
@export var levels: int = 1

func on_monster_entered(ctx: BattleContext, owner: MonsterInstance) -> void:
	if not ctx.rng.chance(chance):
		return
	var allies := ctx.state.get_active_monsters(owner.side)
	if allies.is_empty():
		return
	var chosen: MonsterInstance = allies[ctx.rng.randi_range(0, allies.size() - 1)]
	chosen.tension_level = mini(4, chosen.tension_level + levels)
