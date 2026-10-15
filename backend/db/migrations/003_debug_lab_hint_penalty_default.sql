-- 003_debug_lab_hint_penalty_default.sql
-- Debug labs were published with hint_penalty_pct = 0 (free hints). The default is
-- 10% of the task's points per hint (labkinds.DefaultHintPenaltyPct). Idempotent:
-- only rows still at 0 are touched; later per-lab overrides are kept.
UPDATE lab_definitions SET hint_penalty_pct = 10 WHERE lab_type = 'debug' AND hint_penalty_pct = 0;
