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

## [2026-07-23] build | Sheet sprites, take two: found the real mapping, full artwork coverage

The previous entry's row-order mapping was wrong, but the underlying image set
turned out to be legitimate — the error was in decoding *where* each image
belonged, not the images themselves. Reconstructed the real mechanism: each
embedded image is positioned via a `posObj(sheet, id, row, col, x, y)` call in
the exported HTML's script, giving each image's true spreadsheet row rather
than upload-filename order. Two things had thrown off the first attempt: the
sheet has *two* header rows, not one (so row 2 is monster No.1, not No.0), and
the very first uploaded image is saved as bare `unnamed.png` with no
parenthetical index, which earlier extraction missed entirely, misaligning
everything downstream. Cross-checking a dozen samples against real monster
names confirmed it — "Weaken Beakon" (a bird/vulture icon), "Metal Dragon" (a
robotic-looking icon), "Maulusc" (a crab/shellfish icon), "Exorsus" (a Zombie
demon-mask icon), and an exact match on Slime's icon — where the first
attempt's naive sequential order had produced nonsense for these same rows.

Also surfaced 5 monsters present in the source spreadsheet with confirmed
stats but never given a fixture in any earlier import pass (`florajay.json`,
`whipped_scream.json`, `tree_slime.json`, `golden_cacti.json`,
`drak_slime.json`, all rank F) — created now using the same
structural-fields-only convention as the rest of the roster.

Copied the sheet's icon for every one of the 572 monsters that had no
existing artwork (leaving the 237 already-sourced Fandom-wiki images and the
4 hand-tuned M1 test fixtures — slime/dracky/healslime/golem — untouched, since
those are higher resolution than these 44×44 sheet icons). Extended
`inspect_transparency.gd`/`remove_background.gd` to scan and flood-fill every
opaque image in the directory dynamically instead of a hardcoded id list, and
ran both — all 572 new icons needed the background removed and now report
transparent. Re-ran `fix_sprite_paths.gd` to reconcile `sprite_path` from disk
state. **Artwork coverage is now 808/808 fixtures (100%).** All three headless
suites pass after reimport.

## [2026-07-23] build | Base resistance data for all 803 monsters

Added the source spreadsheet's "Base Resistances" section (30 columns, one per
element/status: Frz, Siz, Bng, Wsh, Crk, Rbl, Zap, Zam, Dnk, Fre, Ice, Wck,
Psn, Crs, Imm, Cnf, Par, Slp, Dzl, DrM, Hck, Fzl, Blt, Abi, Gbs, Ban, Sag, Sap,
Dec, Dim) to `MonsterSpecies` as a new sparse `resistances: Dictionary` field
(code -> raw symbol; a code absent from the dict means normal/unmodified
susceptibility). The raw CSV pull from the earlier stats import
(`sheet1.csv`) already contained these columns — no new scraping needed, just
parsing the two-row merged header properly and pulling 30 more fields per
row alongside the No. column already used to key everything else.

Deliberately stored the **raw symbol** per code rather than converting to a
numeric multiplier: the sheet uses `½` (haldef, presumably "resist"), `↓`
(presumably "weak"), `0` (presumably "immune"), plus `⁎`, `↑`, `↑↑`, and `⇄`
whose exact meaning isn't confirmed yet, and a stray literal `"HP"` value in
~100 scattered cells that looks like a source-spreadsheet data-entry artifact
rather than a parsing bug (it lands in different columns for different
monsters, not a consistent column-shift pattern). Converting to a damage
multiplier now would mean guessing at semantics that matter for the eventual
real battle formula — better to preserve the source data faithfully and
resolve the symbol legend as its own follow-up (same deferral rationale as
the real DQM damage formula work).

All 803 CSV-sourced fixtures got a `resistances` entry, including the 5
created in the previous log entry and the 4 hand-tuned M1 test fixtures
(their stats/skills were left untouched; resistances is a new, previously
empty field so this doesn't affect the battle test's verified numbers). All
three headless suites still pass.

Also fixed a small regression from the previous entry's sprite pass:
`remove_background.gd` was broadened to flood-fill every opaque image
directory-wide, which ran over `montner.webp`/`montner_2nd_form.webp` too —
exactly the pair a much earlier log entry had deliberately left alone
("their only available image is an in-game customization screen with a
varied, non-uniform background, a bad candidate for naive flood-fill"). The
flood-fill did run and produced a bad result (a large framed illustration,
mostly still opaque). Replaced both with their sheet-sourced icons instead
(`unnamed(1).png`/`unnamed(801).png`, the same ones validated earlier in the
sprite-mapping work), which are simple enough for flood-fill to handle
cleanly.

## [2026-07-23] build | Real per-monster movesets, all 803 monsters

Every monster previously defaulted to a single generic "attack" skill. The
source spreadsheet's "Skill" column (e.g. Slime's "Slimer") turned out to be
an exact key into a separate "Skills" tab — 384 rows (326 real skill sets +
58 pure stat-boost sets), each listing up to 10 unlocked actions by SP
threshold. A third "Abilities" tab (285 rows) gives each action's real MP
cost, Type (Spell/Slash/Body/Dance/Breath/Other), Attribute (element or
status), and Range (target scope) — pulled via direct CSV export
(`export?format=csv&gid=...`) rather than WebFetch, since WebFetch's
summarizing model refused to return raw tabular data verbatim. Only these
structural fields were extracted, per the established convention — the
Abilities tab's "Description" column (short mechanical blurbs like move
function) was deliberately not imported, same as monster flavor text never
has been.

Scope was explicitly narrowed before implementing (confirmed with the user):
make real movesets *selectable* with correct names/MP costs, and give each a
*generic* effect inferred from its Type/Attribute/Range — not a bespoke,
game-accurate implementation per move (that would rival the entire original
battle engine in size, and blocks on the same damage-formula research
already flagged as open elsewhere in this log).

Categorization heuristic (`game/tests/tools/import_movesets.gd`), in
priority order: (1) Attribute is a recognized status name (Poison, Sleep,
Paralysis, Confusion, Curse, Dazzle, Silence, Gobstop, Immobilize) → status
effect, creating a new `StatusData` fixture per status with hand-picked
placeholder values the first time it's seen (only `poison` pre-existed); (2)
display name contains "heal" → heal effect; (3) Attribute is a recognized
stat-down name (Sap→defense, Sag→attack, Decelerate→agility) → stat-mod
effect on the enemy; (4) Type is "Dance" → stat-mod buff on self, stat
guessed from name keywords; (5) otherwise → damage effect, magic if
Type=="Spell" else physical, power = `15 + mp*3` (an invented placeholder
scaling, same honesty-about-approximation as the existing damage formula).
Target scope collapses to just SELF or SINGLE_ENEMY — Range values like "All
Enemies"/"All Allies" don't have real multi-target resolution in the battle
engine yet, so they're approximated to the nearer of those two rather than
building real AoE/ally-targeting support in this pass.

62 skill-set entries matching a stat-boost pattern (`ATK +4`, `DEF +8`, etc.)
were excluded from movesets entirely — passive incremental growth via SP
investment, not a battle action, and there's no leveling/SP system to hang
them off yet. A further 57 distinct action names (things like "Frizz Ward",
"AGI Roulette", "Metal Killer", "Steady Recovery") had no matching Abilities
row and were also excluded — these read as passive perks/resistance wards/
traits rather than usable moves (the project already has a separate
`starting_trait_ids` field for passives, but populating it from this data is
its own follow-up, not done here, since these names don't yet have matching
`TraitEffect` implementations).

280 new `SkillData` fixtures and 8 new `StatusData` fixtures were created;
the 7 Milestone-1 hand-tuned skill fixtures (attack, frizz, heal, oomph, sap,
double_slash, poison_breath) were left untouched wherever their id was
already referenced by real data (`id = slugify(display_name)`, matching the
existing convention, means real data naturally lines up with hand-tuned ids
without needing special-casing). One side effect worth noting: Slime's
canonical moveset doesn't include Oomph (that was only ever a Milestone-1
placeholder choice), so two team-roster/UI tests that assumed Oomph was
valid for Slime and Frizz was not needed updating — Slime legitimately knows
Frizz now. `TeamMemberRow` checkboxes now show each skill's MP cost
alongside its name. Also loosened the two remaining hardcoded skill-count
assertions (`== 7`) to a floor check, same recurring pattern as the roster
growing past earlier hardcoded expectations. All three headless suites
pass after reimport.

## [2026-07-23] build | Real skill-point allocation across multiple panels

The previous entry gave each monster one flat, always-known moveset. This
replaces that with the actual DQM mechanic: a monster has several selectable
skill panels, and the player invests a shared pool of skill points across
them, unlocking moves at SP thresholds within whichever panels they choose.

The source spreadsheet doesn't actually contain "which panels can monster X
choose from" — its Monsters-tab "Skill" column only gives ONE panel per
monster, and the Skills-tab reverse-lookup column ("Monsters with this
Skill") turned out to be a redundant re-listing of that same one-to-one
assignment, not real sharing data (verified directly: Dragon Rider's own
"Skill" column already reads "Frizz & Bang", so its appearance in that
panel's monster list isn't additional information). Confirmed with the user
before proceeding: family-based approximation — each monster gets its own
personal panel plus up to 2 more panels drawn from other monsters sharing
its Family — accepted as a reasonable approximation grounded in the source
data, not a claim that it's the game's real per-monster panel assignment.
705 of 803 monsters end up with more than one panel this way; the rest have
an unknown/"???" Family or an isolated one with nothing else to draw from,
so they keep just their personal panel.

New `SkillSetData` resource (`game/database/skillsets/`) models a panel as
an ordered list of thresholds, each either `{sp, kind: "skill", skill_id}`
or `{sp, kind: "stat_boost", stat_name, amount}` (e.g. Montner's own panel:
Zap at 3 SP, ATK+4 at 9 SP, Miracle Slash at 18 SP, DEF+8 at 30 SP...). Stat
boosts are tracked as real data but not yet applied to battle stats — there
is no MonsterLoadout → MonsterInstance bridge in the engine at all yet
(MonsterInstance reads species base stats directly), and building that
bridge is a distinct, substantial integration task of its own, out of scope
here. 220 panels were built (only the ones actually used as some monster's
personal or family-shared panel); `MonsterSpecies` gained
`available_skill_sets` (panel ids) and `total_skill_points`, the latter a
rank-based placeholder (F:100 up to SS:500) pending a real leveling/EXP
system to derive it from properly.

`MonsterLoadout` gained `skill_point_allocation` (panel id → points spent).
`TeamRosterManager.get_unlocked_skill_ids()` computes the live "known" set
from a species' baseline (just "attack") plus whatever each allocated
panel's investment has unlocked; `validate_member` now checks total
allocation against the species' pool and that every equipped skill is
actually unlocked, not just a static list membership check.

UI-wise, cramming multiple panels x up to 10 thresholds each into the
existing compact member row stopped being feasible, so `TeamMemberRow`'s
inline skill checkboxes became a "Skills (n)" button opening a new
`SkillPointDialog` — one SpinBox per available panel (capped by whatever's
left of the shared pool) with that panel's thresholds listed below as
checkboxes, disabled until unlocked. Toggling a threshold off — including
automatically, if a reallocation re-locks something already equipped —
removes it from the loadout the same way the old inline checkboxes did.
All three headless suites pass, including new coverage for allocation,
threshold unlocking/re-locking, and the dialog not crashing on an
out-of-panel equipped skill left over from the previous data model.
