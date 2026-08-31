# Diary

A free-form, one-entry-per-day personal journal — distinct from the [Learning Journal](learning-journal.md) (a topic-tagged "what I learned" log). Writing an entry passively drives two existing systems: the [Habit tracker](overview.md) and the [What Now? task engine](overview.md) — the diary never owns habit-completion or task data itself.

---

## Overview

The Write screen is a single lined-paper textarea for "Today." Saving triggers a background AI pass that reads the entry alongside the user's own habit names and open What Now? task titles (a closed vocabulary — the model may only resolve to ids it was given, never invent a habit or task) and returns highlight spans classified as:

- `habit` — an existing habit was described as done → marks that habit's completion for the entry's date via `habit.Service.SetCompletion`.
- `task_done` — an existing open What Now? task was described as finished → `whatnow.Service.CompleteTask`.
- `task_new` — a new to-do with no matching task → `whatnow.Service.CaptureTask`.
- `buy_new` — a new shopping/errand item → `whatnow.Service.CaptureTask` with the text tagged `#buy`, reusing `ParseCapture`'s existing inline category-tag convention rather than a second category mechanism.

The resolved highlight spans (with `ref_id` pointing at the habit or task they wrote to) are stored on the entry purely for inline rendering — clicking one shows what it resolved to. The "To-Do"/"Buy List" sections shown under an entry are a read-only, category-filtered view of the user's real What Now? inbox, not diary-owned rows.

**Fix English** is a separate, synchronous, unpersisted action: the user clicks it, the current unsaved text is sent for AI grammar/spelling correction, and the response is an ordered array of `same`/`del`/`add` segments (a `del` is always immediately followed by its `add` replacement) rendered as inline strikethrough/insert pairs with per-pair accept/reject plus Accept All/Reject All. Confirming reconstructs the text and saves it — analysis then runs on that corrected content, so habit/task detection always sees the reviewed version.

History has one dataset with two renderings: a plain mobile timeline, and a `lg:` calendar+feed layout (folded into the same page rather than a separate section — the Stitch source screens called this "Chronicle," but it's a breakpoint, not a distinct feature).

---

## UI Layout

```
┌─ Write (Today) ─────────────────────────────┐
│ Tuesday, Oct 24                [Fix English]│
│ ───────────────────────────────────────────│
│ Woke up early... drinking a large glass of  │
│ water (highlighted) ... finished the Q3     │
│ report (highlighted) ...                     │
│                                               │
│ To-Do                    Buy List            │
│ ☐ Call the dentist        ☐ Fresh coffee beans│
└───────────────────────────────────────────────┘
```

Mobile History is a plain newest-first list (date + one-line preview). `lg:` History adds a sticky month calendar (days with an entry get a dot) beside the full feed.

---

## API Endpoints

Gated on permission `content.diary`. No `org_id` scoping — entries are user-owned only, same as `journal`/`sheets`/`habits`.

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/diary` | History list — `?from=`, `?to=`, `?cursor=`, `?limit=`; returns `{entries: [{id, entry_date, preview}], next_cursor}` |
| GET | `/api/diary/today` | Get-or-create today's entry |
| GET | `/api/diary/{date}` | Get one entry (`YYYY-MM-DD`) + its highlights |
| PATCH | `/api/diary/{date}` | Upsert `content`; enqueues a `diary_analyze` job if `sha256(content)` changed since the last analysis |
| POST | `/api/diary/{date}/fix-english` | Synchronous grammar-correction diff for the given `content` — not persisted |

---

## Database Schema

```sql
diary_entries (
  id, user_id, entry_date date, content,
  ai_analysis jsonb,     -- {highlights: [{start,end,text,kind,ref_id}]}
  analyzed_hash text,    -- sha256(content) as of the last completed analysis
  created_at, updated_at,
  unique (user_id, entry_date)
)
```

No separate checklist/highlight table — habit completions live in `habit`'s own `completions` table and to-dos live in `whatnow_tasks`; `diary_entries.ai_analysis` only records which span resolved to which existing (or newly created) id, for rendering.

---

## AI Analysis (`diary_analyze` background job)

Enqueued from the `PATCH` handler via the standard `jobs.Enqueue(..., LLMPayload{Task: "diary_analyze", EntityID: entryID})` path (same job runner as `course_outline`/`roadmap_generate`), handled in `backend/internal/jobs/handlers/llm.go`. Runs off the request path so saving stays fast and the AI call happens at most once per distinct content version (`analyzed_hash` short-circuits a re-run when content is unchanged).

Re-analysis dedup is text-equality only: a returned span whose text case-insensitively matches one already recorded on the entry is skipped, so editing later in the day doesn't re-fire `SetCompletion`/`CaptureTask` for sentences already processed.

`ponytail: dedup is exact-text matching, not semantic — a rephrased mention of an already-processed sentence will re-fire. Upgrade to embedding/fuzzy dedup only if duplicate completions/tasks show up in practice.`

---

## Fix English

`POST /api/diary/{date}/fix-english` calls the AI provider synchronously (`JSONMode`) with the given content and returns `FixEnglishResponse{segments}` — no DB write. The frontend owns all review state (per-pair accept/reject) and calls `PATCH` itself once the user confirms, exactly like any other content edit.
