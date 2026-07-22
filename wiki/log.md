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

## [2026-07-23] build | Bestiary starter roster (76 monsters) + monster artwork

Added the remaining 76 monsters from the game's 80-entry starter bestiary (rank F,
real HP/MP/ATK/DEF/AGI/WIS stats), plus a new `sprite_path` field on
`MonsterSpecies` wired to real official artwork — 80 images sourced from the
Dragon Quest Fandom wiki's bestiary page and downloaded into `game/assets/monsters/`
(as `.webp`, matching the CDN's actual served format despite `.png`-looking URLs).
The user explicitly accepted the copyright risk of using official artwork after
being warned; see conversation history for that exchange. The 3 pre-existing M1
test fixtures (slime/dracky/healslime) kept their original small hand-tuned stats
(load-bearing for the M1 battle test's hand-verified numbers) and only gained a
sprite_path; one bestiary entry (#078 Mohawkling) has an image but no fixture,
since no source could confirm its stats. Two more test assertions were loosened
(exact-match family/combined-filter checks) since the larger roster now has
multiple monsters matching those queries. All three headless suites still pass.

Separately, research into the authentic Dragon Quest Monsters damage formula
completed: no reverse-engineered formula exists for this exact 2020/2023 mobile
title, but a consistent formula corroborates across three related sources (a
sibling "SP"-engine fan blog, the DQM Joker 2 mechanics wiki, and a GameFAQs guide
for the original GBC game this remake is based on): `BaseDamage = ATK/2 - DEF/4`,
random variance of `±(BaseDamage/16 + 1)`, critical hits at `ATK × 0.95-1.05`
(defense ignored), multi-hit as the same roll × a flat per-skill percentage, and
hard-zero (not floor-1) damage for elemental immunity. Implementing this into
`DamageFormula`/`DamageEffect` — including adding critical hits, which don't exist
in the engine yet — is a substantial change touching already-tested code and is
planned as its own follow-up, not yet done.
