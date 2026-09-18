# Knowledge Captures

The "I screenshotted a reel/LinkedIn post, downloaded a PDF, or saved a link — and never opened it again" problem. Captures is the inbox that sits in front of the [Learning Journal](learning-journal.md) and [SRS](learning.md#spaced-repetition-sm-2): drop in a screenshot, PDF, or link, and it comes out the other side as either a journal note or a drillable flashcard, already checked against what you've already got.

---

## Pipeline

```
POST /api/captures — one endpoint, four sources, batchable in one request:
  multipart/form-data, one or more "file" fields → image or pdf (auto-detected from
                                                    magic bytes — no per-type route)
  application/json {urls: [...]}                 → link
  application/json {html: [...]}                 → raw pasted HTML (e.g. copied page
                                                    source) — text extracted synchronously
                                                    at creation, no fetch needed at all
        │  each item → its own row, status=pending, file → MinIO (or source_url/
        │  extracted_text stored directly for link/html)
        ▼
202 Accepted — capture id(s) returned immediately, nothing blocks on AI
        │  captures.process job (internal/jobs) per capture, picked up by a worker
        ▼
extract (internal/captures/extract.go):
  image → nothing extracted server-side — the image itself is attached to the AI call
          as a vision input (no OCR binary; both configured providers, Anthropic and
          Gemini, read images natively — see ai.CompletionRequest.Image)
  pdf   → pdftotext (poppler-utils, shelled out, already in the backend image)
  link  → fetched through the same SSRF-guarded transport internal/gitlab uses for
          admin-configured URLs (internal/netguard.GuardedTransport), then a minimal
          dependency-free HTML text/title walk (golang.org/x/net/html)
  html  → already extracted at creation time (same HTML walk, just run synchronously
          since there's no network fetch involved) — this stage is a no-op
        │
        ▼
one AI call — ai.CaptureStructureSystemPrompt — classifies AND structures in one shot:
  kind=note     → category, subcategory, title, content (markdown)
  kind=question → title = the question, content = the answer
        │
        ▼
status=ready — surfaced in the inbox (GET /api/captures?status=ready)
        │  user reviews (GET /api/captures/{id} — includes live-computed similar matches)
        ▼
POST /api/captures/{id}/promote
  kind=note     → learning_journal_entries, via the journal's own CreateEntry/UpdateEntry
                  (title-trigram dedup already built there — see journal.md)
  kind=question → srs_cards (source_type='capture') — a personal SM-2 card, no course
                  needed (srs_cards was never actually locked to course modules)
        │
        ▼
status=promoted — capture stays around linking to whatever it became (provenance),
                   never deleted. A dismissed-not-promoted capture stays visible too
                   (status=dismissed) — nothing captured just disappears silently.
```

On any stage failure the capture moves to `status=failed` with `error_message` set, retryable via `POST /api/captures/{id}/retry` — never left silently stuck in `processing`.

---

## Why no OCR, no pgvector, no new "captures" content silo

Three real "build new infra" temptations turned out to already have a smaller answer once the actual code was read, not just the docs:

- **No Tesseract/OCR.** The two configured LLM providers (`internal/ai`) both accept image input natively. `CompletionRequest.Image` (base64 + media type) is a small addition to the shared provider interface, implemented for both Anthropic (image content block) and Gemini (OpenAI-compatible `image_url`) — one AI call reads *and* structures the screenshot, instead of a separate OCR pass feeding a second text call. PDFs still need `pdftotext` (poppler-utils) since sending a whole PDF as a vision input isn't reliable across providers for text-heavy documents — that's the one new system binary in the Docker image.
- **No pgvector/embeddings.** `journal.Repo.FindSimilarEntries` already does pg_trgm title-similarity dedup, with its own code comment already flagging embeddings as the upgrade path *if* trigram proves insufficient in practice. Captures reuses that exact mechanism for `kind=note` (via the normal `CreateEntry`/`StructureEntry` path), and adds the same trigram technique to `srs_cards.front` for `kind=question` (`idx_srs_cards_front_trgm_capture`, partial index, capture-sourced cards only). The AI-generated title is already clean, normalized text, not raw OCR noise — same bet journal already made.
- **No new SM-2 schema.** `srs_cards` looked course-locked in `learning.md`, but the actual table (`001_baseline.sql`) never had a `module_id` column — `question_id`/`mistake_entry_id` are both nullable and `source_type` is a free string already used for `'mistake'`-sourced cards outside any course. `source_type = 'capture'` needed zero migration.

What *is* new infra, deliberately: the `captures` table/domain itself, the `captures.process` async job, `ai.CompletionRequest.Image` on the shared provider interface, `netguard.GuardedTransport` promoted from gitlab-only to a shared helper (captures' link fetch needed the identical SSRF defense), and `storage.StorageClient.Download` (the job reads an uploaded image/PDF back server-side, which nothing needed before).

---

## API

```
POST   /api/captures                multipart: one or more "file" fields (jpeg/png/webp/pdf,
                                     ≤20MB each) — OR — JSON: {urls?: string[], html?: string[]}
                                     up to MaxItemsPerRequest (20) items per call either way;
                                     returns 202 + Capture[] (one bad item 422s the whole call,
                                     but every prior successfully-created item in the same
                                     multipart batch is still returned, not rolled back)
GET    /api/captures?status=        list, newest first
GET    /api/captures/{id}           detail + live similar_entries (journal entries or SRS cards)
POST   /api/captures/{id}/retry     re-queue a failed capture
POST   /api/captures/{id}/dismiss   mark reviewed-and-skipped (stays visible, never deleted)
POST   /api/captures/{id}/promote   {category?, subcategory?, title?, content?, merge_into_id?}
                                     — omitted fields fall back to the AI's own suggestion;
                                     merge_into_id appends onto an existing journal entry, or
                                     links (never merges) an existing SRS card
```

Every item in a `POST /api/captures` batch is validated up front (URL format, HTML has extractable text, mime-sniffed file type) before anything is created — one bad item 422s the whole call with none of the batch persisted, rather than leaving a partial set of created-but-unreturned rows behind. A failure *after* validation (storage/DB error) is a genuine infra fault, not something the caller could fix by retrying with different input.

Gated on the `content.captures` permission (same roles as `content.learning_journal`: member, mentor, org_admin, tenant_admin).

---

## DB Schema

```sql
captures (
  id, user_id,
  type              text NOT NULL,              -- image | pdf | link
  storage_key       text,                       -- MinIO object (image/pdf)
  source_url        text,                       -- link only
  status            text NOT NULL DEFAULT 'pending',
                    -- pending | processing | ready | failed | promoted | dismissed
  extracted_text    text,                       -- null for image (vision-only path)
  kind              text,                       -- note | question, set once ready
  category, subcategory, title, content         text,
  journal_entry_id  uuid REFERENCES learning_journal_entries,
  srs_card_id       uuid REFERENCES srs_cards,
  error_message     text,
  created_at, processed_at
)
```

Indexes: `(user_id, status, created_at DESC)` for the inbox; `idx_srs_cards_front_trgm_capture` (partial, `source_type = 'capture'`) added to the existing `srs_cards` table for the question-kind dedup.

See `backend/db/migrations/033_captures.sql`.

---

## Edge Cases

- **AI unavailable at process time** → capture marked `failed` immediately (not retried blindly) with a clear reason; `retry` re-queues once the provider's back.
- **Scanned/image-only PDF** → `pdftotext` produces no text → `failed`, not silently promoted with empty content.
- **Link fetch hits a private/internal address** → blocked at dial time by `netguard.GuardedTransport`, same defense as GitLab self-hosted URLs — a capture can't be used to probe internal infrastructure.
- **Duplicate job run** (retry race, at-least-once delivery) → `Repo.MarkProcessing`'s `RowsAffected` guard makes a second concurrent run a no-op.
- **Promote race** → `promote` requires `status = 'ready'`; a capture already `promoted`/`dismissed` returns a 409, not a second journal entry/card.
