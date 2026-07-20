-- 018_webauthn_credentials.sql
-- Passkey (WebAuthn) login — additive auth method alongside password/OAuth.
-- One row per registered credential (a user may register several: laptop,
-- phone, security key). Columns map 1:1 onto go-webauthn's webauthn.Credential
-- so a row can be loaded straight into the library without extra joins.
CREATE TABLE webauthn_credentials (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    credential_id    bytea NOT NULL UNIQUE,
    public_key       bytea NOT NULL,
    attestation_type text NOT NULL DEFAULT 'none',
    transports       text[] NOT NULL DEFAULT '{}',
    aaguid           bytea NOT NULL DEFAULT '\x',
    sign_count       bigint NOT NULL DEFAULT 0,
    clone_warning    boolean NOT NULL DEFAULT false,
    backup_eligible  boolean NOT NULL DEFAULT false,
    backup_state     boolean NOT NULL DEFAULT false,
    nickname         text NOT NULL DEFAULT 'Passkey',
    created_at       timestamptz NOT NULL DEFAULT now(),
    last_used_at     timestamptz
);

CREATE INDEX idx_webauthn_credentials_user_id ON webauthn_credentials(user_id);
