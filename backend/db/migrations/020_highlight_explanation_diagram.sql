-- ═════════════════════════════════════════════════════════════════════════
-- Migration 020 — highlight_explanation_diagram
-- ═════════════════════════════════════════════════════════════════════════
-- Adds an optional Mermaid flowchart alongside the cached AI explanation —
-- the AI supplies it only when a diagram actually helps (e.g. a process or
-- decision flow), so this stays NULL for plain term definitions.

ALTER TABLE public.highlight_explanations
    ADD COLUMN diagram text;
