-- ══════════════════════════════════════════════════════════════════════════
-- 002_merge_audit_logs.sql — rollback
--
-- Recreates the audit_log table structure (DDL copied from 001_baseline.sql).
-- NOTE: this restores the empty table only. Rows merged into audit_logs by the
-- up migration cannot be un-merged — audit_logs does not record which rows
-- originated from audit_log — so historical data is not recovered.
-- ══════════════════════════════════════════════════════════════════════════

CREATE TABLE public.audit_log (
    id bigint NOT NULL,
    tenant_id uuid,
    actor_id uuid,
    action text NOT NULL,
    entity_type text NOT NULL,
    entity_id text NOT NULL,
    diff jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE public.audit_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);

CREATE INDEX idx_audit_log_entity ON public.audit_log USING btree (entity_type, entity_id);
CREATE INDEX idx_audit_log_tenant_created ON public.audit_log USING btree (tenant_id, created_at DESC);

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.users(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES public.organizations(id) ON DELETE SET NULL;
