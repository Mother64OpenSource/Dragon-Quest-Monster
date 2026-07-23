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

## [2026-07-23] build | Milestone 4: playable battle screen (two-window local duel)

The battle engine (Milestone 1) was fully built and headless-tested but had
never been wired to anything visual, and separately nothing anywhere ever
turned a saved team into a real battle — `MonsterInstance` always read
straight from `MonsterSpecies`, with no bridge from `MonsterLoadout`. The
user wanted an actually playable battle: no AI needed, just two windows so
they can control both sides themselves. Planned formally (plan file, same
as Milestone 3) before implementing, given the size and the architectural
questions involved.

Investigated `TurnManager.run_turn()` first and confirmed it's fully
synchronous end to end — no `await` anywhere in the call chain, and
`ActionProvider.get_action()` returns a value immediately. A real UI can't
make `get_action()` itself wait on a click, so rather than touching the
engine, the UI pre-collects one `Action` per active monster into the
existing `ScriptedActionProvider` (reused as-is via `set_queue()`) and only
calls `run_turn()` once both sides have submitted for the round — which
also happens to be the classic "pick everyone's move, then watch it play
out" DQM turn structure, not just a technical workaround.

New `TeamToBattleBridge.build_team()` (`game/battle/bridge/`) turns a
`SavedTeam` into `Array[MonsterInstance]`, mirroring the existing
test-fixture builder's construction pattern but sourcing `learned_skills`
from the player's actual `equipped_skill_ids` rather than a species'
full default list. New `game/ui/battle/`: `BattleController` (owns the
`BattleEngine` + two action-queue providers, gates `run_turn()` on both
sides submitting, exposes `turn_resolved`/`battle_ended` signals),
`BattleSideView` (per-window UI: both parties' HP/MP, the active monster's
skill buttons disabled by MP cost, a translated event log, win/lose
screen), and `BattleSetupScreen` (pick two saved teams, launch the duel).
`active_slot_count` is fixed at 1 for this milestone — the only slot count
the engine has ever been tested with; bench members still auto-backfill on
faint (already engine behavior), but there's no player-chosen switch-in
hook, so with one active slot there's always exactly one legal target and
the UI auto-targets rather than showing a target picker.

Two real OS windows, one process, no networking: the main window becomes
side_a's view, and a second `Window` node is spawned for side_b, both
holding a `BattleSideView` pointed at the same in-memory `BattleController`
— no serialization or loopback connection involved, just two Control trees
sharing one Godot process's memory, matching "control both, fight myself."

Hit a real GDScript gotcha writing the headless tests: lambdas capture
local variables *by value*, so a probe like `func(x): my_var = x` never
propagates back to the enclosing scope, while `func(x): my_array.append(x)`
does (appending mutates the same underlying Array object) — three tests
silently read stale initial values (a count stuck at 0, a string stuck at
"") until switched to the append pattern already used elsewhere in this
project's tests. Also hit a plain type bug: `ScriptedActionProvider.set_queue()`
expects a strictly-typed `Array[Action]`, and passing an untyped `[action]`
literal fails at runtime.

New `BattleUiTestRunner` (15 checks): bridge construction, both-sides-must-
submit gating, auto-targeting for enemy- vs self-targeted skills, a full
scripted 1v1 battle running to a deterministic winner, and
`BattleSideView` rendering/disabling the right skill buttons. All four
headless suites (this one plus the three from earlier milestones) pass.
Real dual-window behavior (titles, live updates in both windows, actually
clicking through a duel) can't be exercised by a headless `SceneTree` and
is manual-only, same as Milestone 3's drag-and-drop — needs an in-editor
F5 run to confirm.

## [2026-07-23] build | Correction: real slot-based skill panel quota

The family-based panel system shipped with a flat "personal panel + up to 2
shared" cap for every monster (3 panels max, regardless of species). The
user pointed out the real games vary this by the monster's "slots" — 1 slot
→ 3 total panels, 2 slots → 4, 3 slots → 5, 4 slots → 6 (i.e.
`total = slots + 2`). Web research into wiki pages for this specific title
turned up mostly stub sections (e.g. Dragon Rider's own "Iru and Luca"
entry has an empty "Rank and Slot No." section), so this came from the
user's own knowledge of the games rather than a source found here.

The slot count itself was already sitting unused in the data: the source
spreadsheet's "Size" column (e.g. "S [1]", "P [2]", "H [3]", "G [4]") has
exactly this number in brackets — 577 monsters at 1 slot, 134 at 2, 79 at
3, 13 at 4. Updated `build_family_panels.ps1` to read it and compute each
monster's shared-panel quota as `slots + 1` instead of a flat `2`, then
re-ran `import_skill_panels.gd` to regenerate all 803 monsters'
`available_skill_sets`. Verified against a 4-slot monster (Stalagosaur,
"G [4]"): now gets 6 panels (1 personal + 5 shared) as expected; 1-slot
monsters like Slime are unaffected (quota was already 2, matching the old
flat cap). All four headless suites still pass.

## [2026-07-23] build | Milestone 5: multi-slot grid battles, real dual windows, Orders

Milestone 4 shipped a playable but limited duel: exactly one monster active
per side, auto-targeted (since only one legal target ever existed), and a
"2 windows" claim that turned out not to actually separate. The user wanted
what the real games look like: up to 4 monsters active and individually
commandable per side, arranged in a grid, real separate OS windows, and a
working "Orders" command (previously a disabled stub).

Before touching anything, verified the engine could take this with zero
modification (the whole point of Milestone 4's design was staying out of
`game/battle/**`): read `battle_setup.gd`, `faint_handler.gd`,
`turn_manager.gd`, `action_resolver.gd`, `action_executor.gd`, and
`battle_state.gd` directly and confirmed every one of them is already
slot-count-generic — `send_out_initial` loops `for slot in
range(active_slot_count)` with no hardcoded slot 0, `FaintHandler` backfills
into the specific vacated slot, and `TurnManager`/`ActionResolver`/
`ActionExecutor` key everything off `instance_id`, never slot index, so
several simultaneous actions per side already resolve correctly through the
existing priority/agility/RNG/submission-index ordering. `BattleState.set_active_at(side,
slot, team_index)` already existed and was genuinely unused for anything
except the two automatic paths (initial send-out, faint backfill) — a
voluntary mid-battle swap needed no new engine API, just a caller.

Also found the actual cause of the windows not separating: Godot's project
setting `display/window/subwindows/embed_subwindows` defaults to `true` and
nothing in `project.godot` overrode it, so the `Window` node
`BattleSetupScreen` spawns for side_b was rendering embedded inside the main
window instead of as a real separate OS window. Added
`window/subwindows/embed_subwindows=false` to `project.godot`'s `[display]`
section — a one-line project setting, not a UI bug.

`active_slot_count` is now fixed at 4 for both sides (was 1) — a team
smaller than 4 just leaves the remaining slots empty, already handled
gracefully by the engine (`get_monster_at` returns `null` past a team's
size, and `TurnManager` already skips a null/fainted monster). `BattleController`
was restructured from one ready-flag per side to per-slot tracking:
`_pending_slots[side]` snapshots which slots have a living monster at the
start of each round, `_submitted_slots[side]` tracks which of those have
acted, and the round resolves once every pending slot on both sides has
submitted. New `submit_fight(side, slot, skill_id, target_instance_id)`
replaces the old single-target auto-targeting — with up to 4 enemies now
possibly active, the player has to actually pick one, so `BattleSideView`'s
battlefield grid switches into a clickable target-picker once a
single-enemy skill is chosen (self-targeted skills still submit
immediately, no picker needed). New `submit_swap(side, slot,
bench_instance_id)` implements "Orders": swaps a living bench monster into
the given slot via the existing `set_active_at`, consuming that slot's
action for the round — the incoming monster gets no queued action and
naturally does nothing this turn (already-existing engine behavior for a
null action), then acts normally starting next round. Disabled with a
tooltip when a side has no living bench monster. "Tactics" remains an
inert stub — only Orders was requested to work.

`BattleSideView` now renders both parties as 2x2 `GridContainer`s labeled
"Position 1-4" (deliberately distinct wording from the earlier
`species.slots` "[Slot N]" display, an unrelated concept that happens to
share the numbers 1-4) and cycles the command panel through each of your
side's not-yet-submitted pending slots in turn. Extended
`BattleUiTestRunner` with checks for: multi-slot pending/ready gating on
asymmetric team sizes (2-member vs 1-member), explicit-target submission,
and the full Orders/swap flow (5-member team, 5th starts on the bench,
swap moves it into an active slot and queues no action for it). All four
headless suites pass. Actually launching two separate OS windows and
clicking through the grid/target-pick/Orders flow live is manual-only,
same category as Milestone 3's drag-and-drop — needs an in-editor F5 run.

## [2026-07-23] build | Window movability + first real visual theme

Two smaller fixes/polish requested after trying Milestone 5: the second
battle window appeared unmovable, and the whole UI was still 100% bare
default Godot gray theme (never styled since Milestone 3). For the window,
explicitly set `unresizable`/`borderless`/`exclusive`/`transient` to their
normal values (rather than relying on defaults) and positioned it offset to
the right of the main window on open, rather than stacked exactly on top of
it — the likely real cause of "it won't move," since dragging the top
window off an identically-positioned pair can look like nothing happened.

Added `game/ui/theme.tres`, a small dark-slate theme (rounded panels,
amber accent on hover/press, styled progress bars) applied project-wide via
`project.godot`'s new `[gui]` `theme/custom` setting — affects the team
builder too, not just battle. Added the "Opponent"/"Your Party" section
headers the battle screen was missing entirely, and color-coded HP bars
(green/amber/red by percentage) for an at-a-glance read.

## [2026-07-23] build | Milestone 6: a monster's own slots consume real space

Milestone 5 gave every monster exactly one of the 4 active positions
regardless of its own `species.slots` (1-4, the synthesis-size field shown
as "[Slot N]"). The user wanted that field to actually matter: a 2-slot
monster occupies 2 of the 4 positions, a 4-slot monster all of them —
matching the real games, where bigger monsters take up more formation room.

Unlike Milestone 5 (confirmed zero engine changes needed), this genuinely
required touching engine code — `BattleSetup._send_out_side` and
`FaintHandler`'s backfill both assumed a strict 1 team-member : 1 slot
mapping. `TurnManager`/`ActionResolver` still needed no changes at all:
they already key everything off `instance_id`, so a monster spanning 2 slot
indices just means `get_monster_at` returns the same instance for both —
the existing per-instance action queue already treats the second lookup as
a harmless no-op, the same way a fainted/empty slot already was.

`BattleSetup._send_out_side` now greedily packs the team in order: a
monster that fits the remaining slot budget claims all its slots at once
and packing advances; one that doesn't fit is left on the bench and
packing tries the *next* team member (who might be smaller and fit)
rather than giving up on the rest of the team. `FaintHandler` applies the
same greedy logic to backfill: a fainted monster's full *vacated slot
range* (always contiguous, since it was placed as one contiguous run) gets
refilled by one or more fitting reserves in team order; if nothing fits
the remainder, those slots just stay empty until a future faint/backfill
cycle rather than forcing a fit or crashing. New `BattleState` helpers:
`get_slots_for_team_index` (which active-slot indices a team member
currently occupies) and an extended `get_first_reserve_index(side,
max_size)` (skips a reserve too big for the room actually available).

`BattleSideView` dropped the rigid 2x2 `GridContainer` for an
`HFlowContainer` — a 3-of-4-slots monster can't be expressed as a clean
rectangle in a fixed 2-column grid (it'd cover one full row plus half of
the next), so a flow layout that wraps naturally was simpler and more
honest than fighting grid geometry. Cards render once per unique active
monster (not once per raw slot index — a multi-slot monster would
otherwise draw its own card 2-4 times), with width scaled by
`species.slots`: a 4-slot monster's card is roughly 4x as wide as a 1-slot
one and ends up alone on its own row simply because nothing else fits
beside it. The "Position N" per-card labels from Milestone 5 were dropped
along with the rigid grid (no longer a stable, meaningful number once
cards flow and resize); the command panel's "Commanding" indicator now
names the actual monster instead.

Extended `BattleUiTestRunner` with real fixtures at each slot size (aamon=2,
aquarion=3, asura_zoma=4) covering: a 2-slot + two 1-slot team packing
correctly; a 4-slot monster occupying the whole roster alone; a 3-slot +
4-slot + 1-slot team where the 4-slot monster is skipped (doesn't fit the
remaining room) while the smaller, later 1-slot monster still gets placed;
and fainting a 2-slot monster backfilling both vacated slots from two
1-slot bench reserves. Re-ran the Milestone 1 hand-scripted battle test
specifically to confirm the packing change is fully backward-compatible —
all of its fixtures are 1-slot, so packing degenerates to the old 1:1
behavior, and it still passes byte-for-byte identical. All four headless
suites pass.
