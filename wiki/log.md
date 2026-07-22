# Log

Append-only chronological record. Newest entries at the bottom. See [CLAUDE.md](../CLAUDE.md) for the entry format.

## [2026-07-21] setup | Wiki scaffolded

Initialized the LLM Wiki structure (`raw/`, `wiki/{summaries,entities,concepts,decisions}`, `CLAUDE.md`, `index.md`, `log.md`) and git repo. No sources ingested yet.

## [2026-07-22] build | Milestone 1: deterministic battle engine core

Added `game/` (new top-level dir, documented in CLAUDE.md) with a Godot 4/GDScript
deterministic battle engine: seeded RNG, composable skill effects (damage/heal/status/
stat-mod), status & trait systems, event bus, turn resolution pipeline, and a headless
test harness (`game/tests/`) running a fully scripted, hand-verified 4-turn battle.
Team builder, full database, networking, replay serialization, and real AI are later
milestones. Verification pending: no Godot executable was available on this machine to
run the harness — checked by static review and full manual trace only so far.

## [2026-07-22] build | Milestone 2: Team Builder data layer, Milestone 3: Team Builder UI

Added `game/save/` (SavedTeam/MonsterLoadout resources, TeamRosterManager: CRUD,
reorder, import/export, JSON persistence under `user://teams/`) and reusable
`MonsterDatabase`/`SkillDatabase`/`TraitDatabase` registries replacing the old
test-only fixture loader. Followed by `game/ui/team_builder/`: the project's first
Control-node screen (team list + editor panels, monster search/filter picker,
drag-and-drop member reordering), now the main scene. Both verified with dedicated
headless test suites in the user's Godot 4.7 install, in addition to the existing
battle engine test.

## [2026-07-22] build | Real monster stat data import (S/SS rank batch)

Replaced the placeholder-only monster roster with 189 real monsters (ranks S/SS)
sourced from a community-compiled stat spreadsheet for "Dragon Quest Monsters 2:
Cobi and Tara's Marvelous Mysterious Key", cross-referenced against the game's
Fandom bestiary listing. Only structural/mechanical fields were imported (name,
family, rank, base HP/MP/ATK/DEF/AGI/WIS) — no flavor text/descriptions. Added an
`SS` rank tier above `S` to `MonsterSpecies.Rank`. Known gaps, deferred to later
work: all 189 default to a single generic "attack" skill (the sheet's per-monster
"Skill" column names a moveset/skill-set, not individual moves — actual move data
would require a separate "Skills" tab pull), and none have traits (no `TraitEffect`
implementations exist yet for this batch's trait names, so `starting_trait_ids` is
empty rather than referencing unimplemented traits). The battle damage formula
still uses Milestone 1's invented constants, not the original game's real formula —
that research is in progress separately.
