-- Append-only security event trail (H-26). user_id has no FK on purpose: the
-- trail must survive account erasure and a cascade DELETE would be refused by
-- the trigger below. Retention purge sets mindforge.purge_auth_events for its
-- own transaction only.
CREATE TABLE auth_events (
    id      bigserial PRIMARY KEY,
    user_id uuid,
    event   text NOT NULL,
    ip      text,
    ua_hash text,
    ts      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_auth_events_user_ts ON auth_events (user_id, ts DESC);
CREATE INDEX idx_auth_events_ts ON auth_events (ts);

CREATE FUNCTION auth_events_deny_mutation() RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'DELETE' AND current_setting('mindforge.purge_auth_events', true) = 'on' THEN
        RETURN OLD;
    END IF;
    RAISE EXCEPTION 'auth_events is append-only';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER auth_events_append_only
    BEFORE UPDATE OR DELETE ON auth_events
    FOR EACH ROW EXECUTE FUNCTION auth_events_deny_mutation();
