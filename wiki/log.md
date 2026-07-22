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
