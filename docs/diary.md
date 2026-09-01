# Diary

A free-form, one-entry-per-day personal journal — distinct from the [Learning Journal](learning-journal.md) (a topic-tagged "what I learned" log). Writing an entry passively drives two existing systems: the [Habit tracker](overview.md) and the [What Now? task engine](overview.md) — the diary never owns habit-completion or task data itself.

---

## Overview

The Write screen is a single lined-paper textarea for "Today." Clicking **Analyze** runs a synchronous AI pass over the current text against the user's own habit names and open What Now? task titles (a closed vocabulary — the model may only resolve to ids it was given, never invent a habit or task) and returns detected spans classified as:

- `habit` — an existing habit was described as done → marks that habit's completion for the entry's date via `habit.Service.SetCompletion`. If the habit has a structured entry form (gym/sleep/reading/custom — see `habit.FieldsForHabit`), the model is also shown that habit's field schema (key + kind) and may return a `metadata` object with whichever fields it can confidently read out of the sentence (e.g. a sleep habit's `slept_at`/`woke_up` times) via `habit.Service.SetCompletionMetadata`. Unlisted/hallucinated keys are filtered out before the call (`diary.allowedHabitMetadata`) rather than failing the whole apply.
- `task_done` — an existing open What Now? task was described as finished → `whatnow.Service.CompleteTask`.
- `task_new` — a new to-do with no matching task → `whatnow.Service.CaptureTask`.
- `buy_new` — a new shopping/errand item → `whatnow.Service.CaptureTask` with the text tagged `#buy`, reusing `ParseCapture`'s existing inline category-tag convention rather than a second category mechanism.

Detection and mutation are two separate steps, so the writer reviews before anything is written:

1. **Preview** (`POST /api/diary/{date}/analyze/preview`) — synchronous, unpersisted, same convention as Fix English: the current (possibly unsaved) text is sent as-is, the AI call runs inline on the request, and the response is the detected span list. Nothing is written to habits/tasks yet.
2. The frontend renders each detected span as a card — a checkbox to include/exclude it, an editable title for `task_new`/`buy_new` (becomes the captured task's title), and editable fields for a `habit` span's extracted `metadata` (plain text inputs, prefilled with the AI's values — e.g. a sleep habit's `slept_at`/`woke_up`).
3. **Apply** (`POST /api/diary/{date}/analyze/apply`) — the writer confirms; the frontend flushes a save of the current content first (so the entry's stored text and hash match what was reviewed), then posts the edited/filtered highlight list. The backend re-resolves each kept span against the CURRENT habit/open-task vocabulary (it may have moved since Preview ran), applies the mutations, and persists the resolved list plus `analyzed_hash`.

The resolved highlight spans (with `ref_id` pointing at the habit or task they wrote to) are stored on the entry purely for inline rendering — clicking one shows what it resolved to. The "To-Do"/"Buy List" sections shown under an entry are a read-only, category-filtered view of the user's real What Now? inbox, not diary-owned rows.

Content is mirrored to `localStorage` (`diary-draft-{date}`) on every keystroke as a crash-recovery buffer — read once on mount if it differs from the server's version, cleared once a save round-trips successfully. The server copy remains the source of truth; the draft is local-device only, not synced.

**Fix English** is a separate, synchronous, unpersisted action: the user clicks it, the current unsaved text is sent for AI grammar/spelling correction, and the response is an ordered array of `same`/`del`/`add` segments (a `del` is always immediately followed by its `add` replacement) rendered as inline strikethrough/insert pairs with per-pair accept/reject plus Accept All/Reject All. Confirming reconstructs the text and saves it. The Fix English and Analyze review panels are mutually exclusive — only one is ever open at a time, replacing the write area in place (no modal).

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
| PATCH | `/api/diary/{date}` | Upsert `content` — does not trigger analysis |
| POST | `/api/diary/{date}/analyze/preview` | Synchronous habit/task detection over the posted `content` — returns `{highlights}`, writes nothing |
| POST | `/api/diary/{date}/analyze/apply` | Commits a (writer-edited) `{highlights}` list from a prior preview: applies each kept span's mutation and persists the resolved list |
| POST | `/api/diary/{date}/fix-english` | Synchronous grammar-correction diff for the given `content` — not persisted |

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
```

No separate checklist/highlight table — habit completions live in `habit`'s own `completions` table and to-dos live in `whatnow_tasks`; `diary_entries.ai_analysis` only records which span resolved to which existing (or newly created) id, for rendering.

---

## AI Analysis (Preview / Apply)

`internal/diary.Service.Preview` runs the AI detection call and returns the (validated, but unapplied) span list — `internal/diary.Service.Apply` re-loads the CURRENT habit/open-task vocabulary, resolves each writer-kept span against it (`applyHighlights`), applies the mutations, and calls `Repo.SaveAnalysis`. Both are plain synchronous request-path calls, the same shape as Fix English — there is no background job (an earlier version ran detection+mutation together in a `diary_analyze` job; that's gone now that the writer reviews/edits the result before anything is applied, which needs the detection step to return to the frontend rather than commit directly).

Re-analysis dedup is text-equality only: a kept span whose text case-insensitively matches one already recorded on the entry from a prior Apply is skipped, so editing later in the day and re-analyzing doesn't re-fire `SetCompletion`/`CaptureTask` for sentences already processed. A habit span's `metadata` is the one exception — it's re-applied (upserted) every Apply regardless of dedup, since a corrected/refined value should keep overwriting the stored completion.

`ponytail: dedup is exact-text matching, not semantic — a rephrased mention of an already-processed sentence will re-fire. Upgrade to embedding/fuzzy dedup only if duplicate completions/tasks show up in practice.`

---

## Fix English

`POST /api/diary/{date}/fix-english` calls the AI provider synchronously (`JSONMode`) with the given content and returns `FixEnglishResponse{segments}` — no DB write. The frontend owns all review state (per-pair accept/reject) and calls `PATCH` itself once the user confirms, exactly like any other content edit.
