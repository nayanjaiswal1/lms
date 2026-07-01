-- ════════════════════════════════════════════════════════════════════════════
-- 005_highlights.sql — text highlight flow with shared explanation cache
-- ════════════════════════════════════════════════════════════════════════════

-- Per-user text selections anchored to a content resource.
-- text_hash links to the shared explanation cache.
CREATE TABLE highlights (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    source_type         TEXT        NOT NULL CHECK (source_type IN ('wiki_page', 'lesson', 'problem')),
    source_id           UUID        NOT NULL,
    selected_text       TEXT        NOT NULL,
    text_hash           TEXT        NOT NULL, -- hash(selected_text + source_type) for context-aware cache lookup
    position_start      INT,
    position_end        INT,
    saved_for_revision  BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Global shared explanation cache. One row per unique (text, source_type) pair.
-- serve_count increments on every cache hit — proxy metric for tokens saved.
CREATE TABLE highlight_explanations (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    text_hash     TEXT        NOT NULL UNIQUE,
    selected_text TEXT        NOT NULL,
    source_type   TEXT        NOT NULL,
    explanation   TEXT        NOT NULL,
    model_used    TEXT        NOT NULL,
    serve_count   INT         NOT NULL DEFAULT 1,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_highlights_user_id   ON highlights(user_id);
CREATE INDEX idx_highlights_text_hash ON highlights(text_hash);
CREATE INDEX idx_highlights_source    ON highlights(source_type, source_id);
CREATE INDEX idx_highlights_revision  ON highlights(user_id) WHERE saved_for_revision = TRUE;
CREATE INDEX idx_he_serve_count       ON highlight_explanations(serve_count DESC);
