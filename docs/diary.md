# Diary

A free-form, one-entry-per-day personal journal — distinct from the [Learning Journal](learning-journal.md) (a topic-tagged "what I learned" log). Writing an entry passively drives the [Habit tracker](overview.md) and, separately, owns its own to-do/buy checklist directly (`diary_tasks` — no dependency on `internal/whatnow`).

**"Goal" is the diary page's term for a habit — not a separate concept or table.** The Goals strip under the write area (`DiaryGoalsSection`) is a display + CRUD surface over `habit.Service`: creating a goal creates a habit, checking one off calls the same completion endpoint the Habits page uses, deleting a goal deletes the habit. The `goal` AI-highlight kind (below) reflects the same idea from the writing side — a sentence describing a new recurring intention creates a habit too. Diary never owns goal data itself; see [GoalStatus](#goals) below.

---

## Overview

The Write screen is a single lined-paper textarea for "Today," with two independent buttons on the date line (beside the save-status indicator): **Fix English** and **AI**. Either can be run alone, both, or neither, in any order — they aren't chained. Clicking **AI** runs a synchronous AI pass over the current text against the user's own habit names and open `diary_tasks` titles (a closed vocabulary — the model may only resolve to ids it was given, never invent a habit or task) and returns detected spans classified as:

- `habit` — an existing habit (i.e. goal) was described as done → marks that habit's completion for the entry's date via `habit.Service.SetCompletion`. If the habit has a structured entry form (gym/sleep/reading/custom — see `habit.FieldsForHabit`), the model is also shown that habit's field schema (key + kind) and may return a `metadata` object with whichever fields it can confidently read out of the sentence (e.g. a sleep habit's `slept_at`/`woke_up` times) via `habit.Service.SetCompletionMetadata`. Unlisted/hallucinated keys are filtered out before the call (`diary.allowedHabitMetadata`) rather than failing the whole apply.
- `task_done` — an existing open `diary_tasks` row was described as finished → `Repo.SetTaskDone`.
- `task_new` — a new to-do with no matching task → `Repo.CreateTask` with `kind: "todo"`.
- `buy_new` — a new shopping/errand item → `Repo.CreateTask` with `kind: "buy"`.
- `goal` — a NEW recurring intention with no matching habit → a habit is created for it via `habit.Service.Create`, `Cadence` one of `daily`/`weekly`/`monthly`. If the model actually meant an existing habit, it resolves to `habit` instead — `goal` only fires for genuinely new ones.

Detection and mutation are two separate steps, so the writer reviews before anything is written:

1. **Preview** (`POST /api/diary/{date}/analyze/preview`) — synchronous, unpersisted, same convention as Fix English: the current (possibly unsaved) text is sent as-is, the AI call runs inline on the request, and the response is the detected span list. Nothing is written to habits/tasks yet.
2. The frontend renders each detected span as a card — a checkbox to include/exclude it, an editable title for `task_new`/`buy_new` (becomes the captured task's title), and editable fields for a `habit` span's extracted `metadata` (plain text inputs, prefilled with the AI's values — e.g. a sleep habit's `slept_at`/`woke_up`).
3. **Apply** (`POST /api/diary/{date}/analyze/apply`) — the writer confirms; the frontend flushes a save of the current content first (so the entry's stored text and hash match what was reviewed), then posts the edited/filtered highlight list. The backend re-resolves each kept span against the CURRENT habit/open-task vocabulary (it may have moved since Preview ran), applies the mutations, and persists the resolved list plus `analyzed_hash`.

The resolved highlight spans (with `ref_id` pointing at the habit or task they wrote to) are stored on the entry purely for inline rendering — clicking one shows what it resolved to. The "To-Do"/"Buy List" sections shown under an entry are diary-owned rows (`diary_tasks`, not the What Now? inbox). They're not read-only: checking one off toggles `done`, clicking a task expands it into an editable title + description (an AI-captured title can be cut mid-sentence if analysis ran before the writer finished typing it, and AI capture never fills `description` — that's a manual-only field), and each section has its own always-visible "Add…" row for creating a task by hand rather than waiting for the AI to catch it. `task_new`/`buy_new` highlights additionally dedup against ALL open tasks by normalized title (not just this entry's own prior analysis) — a mention re-analyzed on a later day, or one the model happens to classify under the other kind, links to the existing open row instead of creating a duplicate.

Content is mirrored to `localStorage` (`diary-draft-{date}`) on every keystroke as a crash-recovery buffer — read once on mount if it differs from the server's version, cleared once a save round-trips successfully. The server copy remains the source of truth; the draft is local-device only, not synced.

**Fix English** is its own standalone, synchronous, unpersisted action: a grammar/spelling-correction pass over the current unsaved text, returned as an ordered array of `same`/`del`/`add` segments (a `del` is always immediately followed by its `add` replacement) rendered as inline strikethrough/insert pairs with per-pair accept/reject plus Accept All/Reject All. Nothing is saved and no separate feedback record is stored while reviewing — only the writer's confirm action reconstructs the resolved text and saves it, exactly like any other content edit. The Fix English and Analyze review panels are mutually exclusive — only one is ever open at a time, replacing the write area in place (no modal) — but that's a UI constraint, not a sequencing one: running Fix English does not automatically trigger Analyze, and vice versa.

History has one dataset with two renderings: a plain mobile timeline, and a `lg:` calendar+feed layout (folded into the same page rather than a separate section — the Stitch source screens called this "Chronicle," but it's a breakpoint, not a distinct feature). The feed's `GET /api/diary` list only carries a 150-rune preview per entry (`previewOf`) — clicking a date expands that entry in place to its full text, fetched on demand via `GET /api/diary/{date}`, rather than navigating to the editable per-date page; an "Edit this entry" link inside the expanded view is still the way to actually edit it. The month calendar's day dots still link straight to the editable page (picking a day to write in, not to browse).

---

## UI Layout

At `lg:` (1024px+) the page is a 3-column grid (`.diary-shell` in `diary-theme.css`) — calendar+goals rail, editor, and a dedicated tasks rail, so To-Do/Buy List get their own column instead of stacking under Goals in a narrow sidebar:

```
┌─ Calendar ──┐  ┌─ Write (Today) ─────────────┐  ┌─ To-Do ────────┐
│  <month>    │  │ Tue, Oct 24  Saving…[Fix][AI]│  │ ☐ Call dentist │
├─ Goals ─────┤  │ ───────────────────────────  │  ├─ Buy List ────┤
│ ☐ Stretch   │  │ Woke up early... drinking a  │  │ ☐ Coffee beans │
│ ☑ Read 20p  │  │ large glass of water         │  │                │
│ Add a goal… │  │ (highlighted)...             │  │                │
└─────────────┘  └───────────────────────────────┘  └────────────────┘
```

Below `lg:` there's no grid — a single flowing column in document order: Calendar, Goals, Tasks, then the editor. Mobile History is a plain newest-first list (date + one-line preview). `lg:` History adds a sticky month calendar (days with an entry get a dot) beside the full feed.

---

## Goals

The Goals strip (`DiaryGoalsSection`, its own column under Calendar at `lg:`, sharing the sidebar rail — see UI Layout above) is a display + CRUD surface over the habit tracker, not a diary-owned entity — there is no `diary_goals` table. `internal/diary.Handler.withGoals` joins `GET /api/diary/today` and `GET /api/diary/{date}` with `habit.Service.MonthView`, projecting every habit (not just completed ones) into `GoalStatus{id, name, cadence, done, period}` — `done` reflects the completion period covering the entry's date (`alignPeriod`: the day itself for daily, that ISO week's Monday for weekly, the month's 1st for monthly), and `period` is that same aligned value formatted `YYYY-MM-DD`, returned so the frontend never has to reimplement the alignment to toggle a goal.

Creating, completing, and deleting a goal from the diary page call the habit domain's own endpoints directly — `POST /api/habits`, `PUT`/`DELETE /api/habits/{id}/completions/{period}`, `DELETE /api/habits/{id}` (see [overview.md](overview.md) for the Habit tracker) — via `createDiaryGoalAction`/`toggleDiaryGoalAction`/`deleteDiaryGoalAction` in `frontend/app/(app)/diary/actions.ts`. Creating goes through an extra round trip (`POST /api/habits` then a re-`GET` of the entry) specifically to get back the new goal's server-computed `period` rather than guessing it client-side. The add-goal row only takes a name + cadence — no target-count/weekday/type/custom-field options, unlike the Habits page's full `AddHabitInline` dialog; those still require a trip to Habits.

The `HIGHLIGHT_KIND_LABEL` map (`frontend/lib/diary/highlight-labels.ts`) is the single source for how `habit`/`goal`/etc. highlight kinds are labeled in both the inline `<mark>` tooltip and the analyze review panel — both used to keep their own, inconsistent copy ("Habit" vs "Detected habit", "🎯 New goal" vs "New goal"), which is what made the page read as if habits and goals were unrelated. `habit` and `goal` both surface as "Goal"/"🎯 New goal" now, matching the Goals strip's own terminology.

---

## API Endpoints

Gated on permission `content.diary`. No `org_id` scoping — entries are user-owned only, same as `journal`/`sheets`/`habits`.

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/diary` | History list — `?from=`, `?to=`, `?cursor=`, `?limit=`; returns `{entries: [{id, entry_date, preview}], next_cursor}` |
| GET | `/api/diary/today` | Get-or-create today's entry |
| GET | `/api/diary/{date}` | Get one entry (`YYYY-MM-DD`) + its highlights |
| PATCH | `/api/diary/{date}` | Upsert `content` — does not trigger analysis |
| POST | `/api/diary/{date}/analyze/preview` | Synchronous habit/task detection over the posted `content` — returns `{highlights}`, writes nothing |
| POST | `/api/diary/{date}/analyze/apply` | Commits a (writer-edited) `{highlights}` list from a prior preview: applies each kept span's mutation and persists the resolved list |
| POST | `/api/diary/{date}/fix-english` | Synchronous grammar-correction diff for the given `content` — not persisted |
| GET | `/api/diary/tasks` | List the user's `diary_tasks` — `?tag=`, `?done=` |
| POST | `/api/diary/tasks` | Create a task by hand — `{title, description?, kind, tags}` |
| PATCH | `/api/diary/tasks/{id}` | Partial update — any of `{title, description, done, tags}`, nil/omitted fields left unchanged |
| DELETE | `/api/diary/tasks/{id}` | Remove a task |

---

## Database Schema

```sql
diary_entries (
  id, user_id, entry_date date, content,
  ai_analysis jsonb,     -- {highlights: [{start,end,text,kind,ref_id,metadata?}]}
  analyzed_hash text,    -- sha256(content) as of the last completed Apply
  created_at, updated_at,
  unique (user_id, entry_date)
)

diary_tasks (
  id, user_id, title, description text default '',
  kind text default 'todo',      -- 'todo' | 'buy'
  tags text[] default '{}',
  done boolean default false,
  source_entry_id,               -- the diary entry an AI capture came from, else null
  created_at, updated_at
)
```

Habits (i.e. goals) and their completions live entirely in `habit`'s own tables — diary has no goal table of its own, only the read+CRUD projection described under [Goals](#goals) above. To-dos/buy items are diary-owned (`diary_tasks`, migration 027 — no dependency on `whatnow_tasks`); `description` (migration 030) is a manual-only free-text field never populated by AI capture. `diary_entries.ai_analysis` only records which span resolved to which existing (or newly created) id, for rendering.

---

## AI Analysis (Preview / Apply)

`internal/diary.Service.Preview` runs the AI detection call and returns the (validated, but unapplied) span list — `internal/diary.Service.Apply` re-loads the CURRENT habit/open-task vocabulary, resolves each writer-kept span against it (`applyHighlights`), applies the mutations, and calls `Repo.SaveAnalysis`. Both are plain synchronous request-path calls, the same shape as Fix English — there is no background job (an earlier version ran detection+mutation together in a `diary_analyze` job; that's gone now that the writer reviews/edits the result before anything is applied, which needs the detection step to return to the frontend rather than commit directly).

Re-analysis dedup is text-equality only: a kept span whose text case-insensitively matches one already recorded on the entry from a prior Apply is skipped, so editing later in the day and re-analyzing doesn't re-fire `SetCompletion`/`CreateTask` for sentences already processed. A habit span's `metadata` is the one exception — it's re-applied (upserted) every Apply regardless of dedup, since a corrected/refined value should keep overwriting the stored completion. `task_new`/`buy_new` additionally dedup against ALL of the user's open tasks by normalized title, not just this entry's own prior-Apply highlights (`openTaskByTitle` in `applyHighlights`) — a mention re-analyzed on a later day, or one the model files under the other kind, links to the existing row instead of creating a duplicate.

`ponytail: both dedup paths are exact-text matching, not semantic — a rephrased mention of an already-processed sentence will re-fire. Upgrade to embedding/fuzzy dedup only if duplicate completions/tasks show up in practice.`

---

## Fix English

`POST /api/diary/{date}/fix-english` calls the AI provider synchronously (`JSONMode`) with the given content and returns `FixEnglishResponse{segments}` — no DB write. The frontend owns all review state (per-pair accept/reject) and calls `PATCH` itself once the user confirms, exactly like any other content edit.
