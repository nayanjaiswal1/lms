# Learning Journal

A personal, day-by-day log of what the user learned — free-typed category/subcategory tags, full CRUD, own MCP scope.

---

## Overview

Unlike the [Activity tracker](activity.md) (read-only aggregation of module/quiz/lab/SRS events) and [Habits](overview.md) (lifestyle habit tracking), the Learning Journal is a manual "what I learned today" log the user writes themselves — one entry per topic, dated, under a category → subcategory path they type (Backend / Redis, DSA / Graphs, English / Modal Verbs, ...), no fixed enum on either level.

**v1 has no bespoke AI endpoint of its own.** No auto-structuring of raw notes, no gap-detection, no "needs review" nudges — none of that is built. The only AI-adjacent behavior is duplicate/similar-topic detection on create (`Repo.FindSimilarEntries`, Postgres `pg_trgm` title similarity, same `> 0.3` threshold `courses.Repo.FindSimilarSelfCourse` uses) — purely informational, never merges or blocks. Beyond that, AI access is entirely through the [AI Connector](ai-connector.md)'s `journal:manage` MCP tools — a connected client's own reasoning is the only "AI" in this feature.

---

## UI Layout

A single vertical timeline, newest entry first — a center spine on desktop (cards alternate left/right), a left-aligned spine on mobile. Each entry is a collapsed row (`Aug 11 · English / Modal Verbs` + title) that expands in place on click to show full content; no separate day-group headers, no pan/zoom canvas.

```
┌─ Learning Journal ──────────────────────────────────────────┐
│ [Search…]                                  [+ Add Learning] │
│ [All] [English] [Backend] [DSA]                              │
│         [All Backend] [Redis] [Postgres]                     │
│                                                                │
│  ●──[Aug 11 · English/Modal Verbs]  Can vs Could         ⋮▾ │
│  │                                                            │
│  │        [Aug 10 · Backend/Redis]  Redis Queues     ⋮▾──●  │
└────────────────────────────────────────────────────────────┘
```

Category chips are two rows: the top row picks a category, and once one is picked a second row (indented) narrows by that category's subcategories — `[All <category>]` plus each subcategory seen under it. Category, subcategory, and search are AND-combined URL-state filters that trigger a normal server refetch (`lib/server/journal.ts#getJournalEntries`) — no client-side graph layout to preserve, so no shallow-routing trick is needed. Picking a different top-level category clears the subcategory filter.

---

## API Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/journal` | List the caller's entries, optional `?category=`, `?subcategory=` (only meaningful alongside `category`), and `?q=` filters |
| GET | `/api/journal/categories` | The caller's category → subcategories tree: `[{category, subcategories: [...]}]`, ordered by category then subcategory |
| GET | `/api/journal/{id}` | Get one entry |
| POST | `/api/journal` | Create an entry — response includes `similar_entries` (see below) |
| PATCH | `/api/journal/{id}` | Partial update, nil fields unchanged |
| DELETE | `/api/journal/{id}` | Delete an entry |

Gated on permission `content.learning_journal`. No `org_id` scoping — entries are user-owned only, same as `sheets`/`habits`.

---

## Database Schema

```sql
learning_journal_entries (
  id, user_id, entry_date date, category, subcategory, title, content,
  created_at, updated_at
)
```

- `entry_date` defaults to `CURRENT_DATE` but is settable, so a user can log a past day.
- `category` and `subcategory` are both required free-typed strings (1-60 chars each) — not an enum, not an array, and no FK between them (a subcategory string is only ever interpreted relative to the category on the same row). Added in `018_journal_subcategory.sql` on top of the `017_learning_journal.sql` baseline. Multi-category-per-entry later is an additive `text[]` migration, not a rewrite.
- Indexes: `(user_id, entry_date DESC, created_at DESC)` for the timeline read, `(user_id, category, subcategory)` for the filter chips (also serves plain category-only lookups as a prefix), and a GIN trigram index on `title` backing `FindSimilarEntries`.

---

## Similar-Entry Detection

`Repo.FindSimilarEntries(userID, title, excludeID)` returns the caller's own entries whose title clears the trigram similarity threshold against a given title — cross-category on purpose, since the same topic can resurface under a differently-typed tag. Called automatically after `CreateEntry` (surfaced as `similar_entries` in the create response) and exposed standalone as the `find_similar_journal_entries` MCP tool, so a connected AI can check before logging a near-duplicate.

`ponytail: title-only trigram match, the same mechanism courses already trusts for this; upgrade to pgvector/embedding similarity over content only if trigram misses too many semantically-similar-but-differently-worded entries in practice.`

---

## MCP Tools

Five tools under the `journal:manage` scope — `list_journal_entries`, `find_similar_journal_entries`, `create_journal_entry`, `update_journal_entry`, `delete_journal_entry`. Full tool definitions and the scope's security notes live in [docs/ai-connector.md](ai-connector.md#journalmanage--the-personal-learning-journal-one-scope-like-sheetsmanage).

---

## Search & Filter

`q` is a plain `ILIKE '%term%'` scan over `title`/`content` — no full-text search infra (`tsvector`/`pg_trgm` beyond the title-similarity index above) since this is a personal-scale table with no volume problem to justify one. `category` and `subcategory` are both exact matches; `subcategory` is only applied alongside `category` (the frontend never sends one without the other). All AND-combine when present together.
