# Sheet Tracker

Everything about the problem-list tracker: UI, tab behavior, progress model, subscribe/fork, and the overlap view.

---

## Overview

A curated-list tracker where users work through problems/topics from multiple sheets simultaneously, see which problems appear across sheets (overlap), and track when they solved each one and when to revise it.

Not DSA-specific — works for any topic list (System Design, Frontend, Backend, etc.).

Platform ships with four system-seeded sheets (`is_system = true`): Striver's A2Z, NeetCode 150, Blind 75, Grind 169. These can be subscribed or forked but not edited.

---

## UI Layout

```
┌─[Striver A2Z]─[NeetCode 150]─[Blind 75]─[My Sheet]─[+ Add]─┐
│                                                               │
│  Filter: [All ▾] [Difficulty ▾] [Only Overlapping] [Unsolved]│
│                                                               │
│  #  │ Problem        │ Category │ Diff  │ In Sheets  │ Solved On │ Revision  │
│─────┼────────────────┼──────────┼───────┼────────────┼───────────┼───────────│
│  1  │ Two Sum        │ Arrays   │ Easy  │ [S][N][B]  │ Jun 15    │ Jun 22    │
│  2  │ Binary Search  │ Arrays   │ Easy  │ [S]        │ —         │ —         │
│  3  │ Merge Sort     │ Sorting  │ Med   │ [S][N]     │ Jun 18    │ Jul 1     │
│                                                               │
│  [ Select problems → Create my sheet ]                        │
└───────────────────────────────────────────────────────────────┘
```

---

## Tab Behavior

- **Single tab active** → shows only that sheet's items; "In Sheets" column shows badges for all user-pinned sheets that also contain the same `topic_tag`
- **Multiple tabs selected** (click to toggle) → union of all selected sheets' items, deduped by `topic_tag`; ordered by overlap count descending
- **"+ Add" tab** → opens sheet browser to pin a new sheet

---

## Columns

| Column | Description |
|---|---|
| **#** | Row number within current view |
| **Problem** | Title + optional external link (LeetCode, article, video) |
| **Category** | Topic group (Arrays, DP, Trees, etc.) |
| **Difficulty** | Easy / Medium / Hard badge |
| **In Sheets** | Badge per user-pinned sheet containing this `topic_tag`; clicking badge switches to that sheet |
| **Solved On** | Date user marked done; click checkbox → sets today; click date → clear |
| **Revision** | Next scheduled review; auto-set to `solved_at + 7 days`; editable via date picker |

---

## Filters

- Category dropdown
- Difficulty dropdown (Easy / Medium / Hard / All)
- "Only Overlapping" toggle — hides items that appear in only 1 sheet
- "Unsolved" toggle — hides completed items

---

## Progress Rules

- Progress stored by `topic_tag`, not by `sheet_item_id` — marking "Two Sum" done on Striver's also marks it done on NeetCode 150 and Blind 75 (all share the same `topic_tag`)
- Status cycle: `todo` → `done` → `revisit`
- `solved_at` set when first marked `done`; cleared on reset to `todo`
- `revision_at` auto-set to `solved_at + 7 days`; user can override

---

## Subscribe vs Fork

| | Subscribe | Fork |
|---|---|---|
| Ownership | Not yours | Yours |
| Owner edits flow to you | Yes | No (snapshot at fork time) |
| You can edit items | No | Yes |
| Attribution | "Subscribed" badge | "Forked from X" |
| Progress | Your own (`user_problem_progress`) | Your own |

**Subscribe** — when you want to stay in sync with the owner's curation.
**Fork** — when you want your own version to customize independently.

---

## Create Custom Sheet

1. Multi-select rows (checkbox column)
2. Click "Create my sheet" → name prompt
3. New sheet created with same `topic_tag` values; user is owner

---

## Combine

Select 2+ pinned tabs → "Combine" → name prompt → new sheet that is the union of all selected sheets' items, deduped by `topic_tag` (first occurrence wins for title/category/difficulty/url). Source sheet IDs stored in `source_sheet_ids`. Changes to source sheets do NOT flow into the combined sheet — it is a snapshot at combine time.

---

## Visibility & Sharing

- `private` (default) · `unlisted` (link-only) · `public` (listed in browser)
- Public/unlisted sheets: shareable URL at `/sheets/:slug`
- Public sheets discoverable in sheet browser; sort by subscriber count

---

## API Endpoints

```
-- Browse
GET    /api/sheets/public                  paginated; filter: category, search; sort: subscribers, newest
GET    /api/sheets/:slug                   sheet detail (public/unlisted: no auth; private: owner only)
GET    /api/sheets/:slug/items             items in sheet

-- Manage own sheets
POST   /api/sheets                         body: {name, description, category, visibility}
PATCH  /api/sheets/:id                     body: {name?, description?, visibility?}  (owner)
DELETE /api/sheets/:id                                                                (owner)
POST   /api/sheets/:id/items               body: {title, topic_tag, category, difficulty, external_url, order_index}
PATCH  /api/sheets/:id/items/:itemId       body: {title?, category?, difficulty?, external_url?, order_index?}
DELETE /api/sheets/:id/items/:itemId

-- Combine + Fork
POST   /api/sheets/combine                 body: {sheet_ids[], name, description, visibility}
POST   /api/sheets/:id/fork                creates owned copy; sets forked_from_id

-- Subscribe / Unsubscribe
POST   /api/sheets/:id/subscribe           pins as tab; increments subscriber_count
DELETE /api/sheets/:id/subscribe           unpins; decrements subscriber_count

-- User's pinned sheets
GET    /api/user/sheets                    list owned + subscribed + forked

-- Combined / overlap view
GET    /api/sheets/view?ids=a,b,c          union of items from selected sheet IDs, deduped by topic_tag
                                           each item includes: in_sheets, in_sheet_count, status,
                                           solved_at, revision_at
                                           filter params: category, difficulty, status, overlap_only

-- Progress (upsert by topic_tag — cross-sheet)
PATCH  /api/progress/:topic_tag            body: {status, solved_at?, revision_at?, notes?}
```

### Combined View Response Shape

```json
{
  "data": [
    {
      "topic_tag": "two-sum",
      "title": "Two Sum",
      "category": "Arrays",
      "difficulty": "easy",
      "external_url": "https://leetcode.com/problems/two-sum/",
      "in_sheets": ["striver-a2z", "neetcode-150", "blind-75"],
      "in_sheet_count": 3,
      "status": "done",
      "solved_at": "2024-06-15T00:00:00Z",
      "revision_at": "2024-06-22T00:00:00Z",
      "notes": ""
    }
  ]
}
```

---

## Database Schema

```sql
sheets (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name             TEXT NOT NULL,
  slug             TEXT UNIQUE NOT NULL,
  description      TEXT,
  author           TEXT,
  category         TEXT,
  visibility       TEXT NOT NULL DEFAULT 'private',  -- 'private' | 'unlisted' | 'public'
  is_system        BOOLEAN DEFAULT false,             -- true = platform-seeded
  created_by       UUID REFERENCES users(id) ON DELETE SET NULL,
  forked_from_id   UUID REFERENCES sheets(id) ON DELETE SET NULL,
  source_sheet_ids UUID[],
  subscriber_count INT NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ DEFAULT now(),
  updated_at       TIMESTAMPTZ DEFAULT now()
)

sheet_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sheet_id     UUID NOT NULL REFERENCES sheets(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  topic_tag    TEXT NOT NULL,   -- normalized slug: "two-sum"; overlap detection key
  category     TEXT,
  difficulty   TEXT,
  external_url TEXT,
  order_index  INT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT now()
)

user_sheets (
  user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sheet_id  UUID NOT NULL REFERENCES sheets(id) ON DELETE CASCADE,
  role      TEXT NOT NULL DEFAULT 'subscriber',  -- 'owner' | 'subscriber'
  added_at  TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, sheet_id)
)

-- One row covers every sheet sharing the same topic_tag — cross-sheet progress
user_problem_progress (
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  topic_tag   TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'todo',  -- 'todo' | 'done' | 'revisit'
  solved_at   TIMESTAMPTZ,
  revision_at TIMESTAMPTZ,
  notes       TEXT,
  PRIMARY KEY (user_id, topic_tag)
)
```

### System-Seeded Sheets (inserted in migration, `is_system = true`)

| slug | name | category |
|---|---|---|
| `striver-a2z` | Striver's A2Z DSA | DSA |
| `neetcode-150` | NeetCode 150 | DSA |
| `blind-75` | Blind 75 | DSA |
| `grind-169` | Grind 169 | DSA |
