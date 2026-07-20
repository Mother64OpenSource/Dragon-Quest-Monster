# Dragon Quest Monster Showdown — Project Wiki

This repo is a personal knowledge base for the **Dragon Quest Monster Showdown** project (game/design work), built using the LLM Wiki pattern: raw sources stay immutable, the LLM builds and maintains an interlinked markdown wiki on top of them, and this file is the schema that keeps the maintenance disciplined and consistent across sessions.

You (Claude) own the `wiki/` layer entirely — create pages, update them, cross-link them, keep them consistent. The user owns `raw/` — they decide what goes in, you never edit it.

## Directory structure

```
raw/                    Immutable source material. Never edit these files.
  assets/               Images/attachments pulled in from clipped sources (Obsidian downloads here too)
wiki/                   Everything you write and maintain lives here.
  index.md              Master catalog of every wiki page — read this first when answering a query.
  log.md                Append-only chronological record of ingests/queries/lints.
  summaries/            One page per raw source, written when it's ingested.
  entities/             Pages for concrete "things": characters, monsters, systems, tools, people.
  concepts/             Pages for abstract ideas: mechanics, design philosophies, themes, comparisons.
  decisions/            Design-decision records — what was decided, why, and what alternatives were rejected.
CLAUDE.md               This file. Co-evolve it with the user as conventions get discovered.
```

If a new kind of page doesn't fit `entities/`, `concepts/`, or `decisions/`, propose a new subfolder rather than forcing a bad fit — then document it here.

## Page conventions

Every wiki page (except `index.md`/`log.md`) starts with YAML frontmatter, for Obsidian Dataview compatibility:

```yaml
---
title: Page Title
type: entity | concept | decision | summary
tags: [tag1, tag2]
created: YYYY-MM-DD
updated: YYYY-MM-DD
sources: ["[[Source Page Name]]"]
---
```

Body conventions:
- Use `[[Wiki Link]]` style links (Obsidian wikilinks) to cross-reference other pages, not relative markdown paths.
- Keep a page's lead paragraph as a tight summary — it's what gets skimmed from `index.md` and backlinks.
- When a new source contradicts or updates an existing claim, don't silently overwrite: note it explicitly (e.g. "as of [[Source X]] this changed from... see also open question below") so the revision history of the *idea*, not just the file, is visible.
- Prefer editing/extending an existing page over creating a near-duplicate. Check `index.md` before creating anything new.

## Operations

### Ingest (adding a new source)

1. User drops a file/link/note into `raw/` (or gives you the raw text).
2. Read it fully. Discuss key takeaways with the user before writing anything — this project ingests one source at a time with the user staying involved, not batch/unsupervised.
3. Write a summary page in `wiki/summaries/`.
4. Update or create relevant `entities/`, `concepts/`, `decisions/` pages touched by this source — a single source may touch many pages.
5. Update `wiki/index.md`.
6. Append an entry to `wiki/log.md`.

### Query (answering a question)

1. Read `wiki/index.md` first to find candidate pages.
2. Drill into the specific pages needed — don't re-read the whole wiki.
3. Synthesize an answer with citations back to wiki pages (and raw sources where relevant).
4. If the answer is substantial and reusable (a comparison, an analysis, a synthesis), ask the user whether to file it back into the wiki as a new page rather than letting it disappear into chat history.

### Lint (periodic health check)

When asked to lint the wiki, check for:
- Contradictions between pages
- Stale claims superseded by newer sources
- Orphan pages with no inbound links
- Concepts mentioned repeatedly but lacking their own page
- Missing cross-references between clearly related pages
- Decisions in `decisions/` that a later source appears to invalidate

Report findings; only apply fixes the user confirms, since lint can touch many pages at once.

## index.md format

Organized by category (Summaries / Entities / Concepts / Decisions), each entry as one line:

```
- [[Page Title]] — one-line description (YYYY-MM-DD)
```

### log.md format

Append-only, newest at the bottom. Each entry starts with a consistent prefix so it's greppable:

```
## [YYYY-MM-DD] ingest | Source Title
## [YYYY-MM-DD] query | Short question summary
## [YYYY-MM-DD] lint | What was checked / found
```

## Notes for the LLM

- This file should evolve. If a convention above stops fitting how the user actually works, propose an edit to this file rather than silently deviating.
- Don't create wiki pages speculatively "just in case" — every page should trace back to a source, a decision, or a synthesized answer the user asked to keep.
- The wiki is a git repo — commits are cheap, use them if the user asks for checkpoints, but don't auto-commit without being asked.
