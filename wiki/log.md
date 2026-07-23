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

## [2026-07-23] build | Team Builder image/stats UI + full artwork coverage

`MonsterPickerDialog` now shows a thumbnail per search result and a details panel
(larger image + full stats) on selection; `TeamMemberRow` shows each member's icon.
Separately, sourced artwork for the remaining monsters that lacked it: 145 more
images for the S/SS-rank batch (plus Golem), bringing artwork coverage to 235 of
269 species. Built two small one-off Godot utilities (`game/tests/tools/`,
kept in-repo for reuse) since neither ImageMagick nor .NET's System.Drawing could
decode the WebP files on this machine, but Godot's own `Image` class could:
`inspect_transparency.gd` flags images with no alpha or an opaque background, and
`remove_background.gd` flood-fills a uniform background to transparent from the
image's edges inward (so it never eats into similarly colored regions inside the
subject). Fixed 17 images that had opaque backgrounds — 8 by finding a properly
cutout alternate source image, 10 via the flood-fill tool. Montner and its 2nd
form were left opaque; their only available image is an in-game customization
screen with a varied, non-uniform background, a bad candidate for naive flood-fill.
34 monsters still have no artwork at all (name mismatches with obscure/unlocalized
source titles, e.g. several appear to be exclusive to *Dragon Quest Monsters:
Joker 3*, which was never localized and has almost no fan-uploaded art anywhere).
All three headless suites still pass throughout.

## [2026-07-23] build | Full spreadsheet import: 802 monsters total

Imported the remaining 533 monsters (ranks A-F) from the same community stats
spreadsheet, covering the full 803-row sheet apart from one collision ("Golem",
row 384, left alone since `golem.json` is the hand-tuned M1 test fixture the
battle test's verified numbers depend on). As before, only structural fields
were imported (name, family, rank, base stats) — never the sheet's "Description"
flavor-text column. All default to a single "attack" skill and no traits, same
known gap as the earlier S/SS batch. Loosened two more test assertions
(`search_by_name('drac')`, `filter_by_rank(C)`) to membership checks, since the
802-monster roster now has other name/rank matches beyond the original 4 test
fixtures. No artwork sourced for this batch yet. All three headless suites pass.

## [2026-07-23] build | Correction: reverted a bad sprite import, added Brushead

The user's downloaded HTML export of the stats spreadsheet
(`[Guide] Dragon Quest Monsters 2... - Google Drive.html`) contains 808 embedded
images (`unnamed(N).png`, 44×44). These sorted into a perfectly sequential
1–803 order, which looked like strong evidence they were per-monster sprite
thumbnails aligned to the sheet's rows — so a full mapping was built from it:
802 images copied into `game/assets/monsters/`, `sprite_path` set on all
matching fixtures, and a new `brushead.json` fixture created from row 78's
confirmed stats (`Family: Devil, Rank F, HP 1412, MP 463, ATK 752, DEF 728,
AGI 887, WIS 707` — this row previously had no confirmed stats). Direct visual
inspection of the copied files then disproved the mapping entirely: the file
for "Slime" was a flower, "Dracky" was a bird, and the raw `unnamed(1).png`
was an unrelated smiley face. These embedded images are not per-monster
artwork in row order — what they actually depict in the source document is
still unknown (possibly icons from a different tab, e.g. Skills/Traits/Items,
or inline comment attachments) and needs fresh investigation before this
source is tried again for sprites.

Recovery (surgical, not a full git revert, since 1900+ uncommitted files spanning
several legitimate prior sessions were sitting in the tree): identified the 15
species whose pre-existing correct artwork had been overwritten by the bad
bulk copy, re-downloaded all 15 from their original source URLs, deleted the
other 787 wrongly-copied files, re-ran the flood-fill background tool
(`game/tests/tools/remove_background.gd`) on the 10 of those 15 that needed
it, then wrote a one-off reconciliation script
(`game/tests/tools/fix_sprite_paths.gd`) that sets each fixture's `sprite_path`
from what actually exists on disk in `game/assets/monsters/` rather than trusting
any previously-recorded value — 220 fixtures corrected to their real image,
567 had a now-invalid `sprite_path` removed (including `brushead.json`, which
has confirmed stats but no artwork). Artwork coverage is back to its last
known-good state: 237 real images. All three headless suites pass after
reimport.
