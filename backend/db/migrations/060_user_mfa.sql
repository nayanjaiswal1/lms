-- M-01: TOTP MFA. secret_enc is the AES-GCM sealed secret (secrets vault);
-- enabled_at stays NULL until the first code is confirmed. last_step blocks
-- replay of an already-accepted 30s code. Recovery codes are stored hashed and
-- are single-use.
CREATE TABLE user_mfa (
    user_id    uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    secret_enc bytea NOT NULL,
    enabled_at timestamptz,
    last_step  bigint NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE user_mfa_recovery_codes (
    id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id   uuid NOT NULL REFERENCES user_mfa(user_id) ON DELETE CASCADE,
    code_hash text NOT NULL,
    used_at   timestamptz,
    UNIQUE (user_id, code_hash)
);
