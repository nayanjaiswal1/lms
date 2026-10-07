-- Per-user privacy choices: AI processing consent (DPDP s.6, H-20) and the
-- nominee a user designates to exercise their rights (DPDP s.14, H-28).
CREATE TABLE user_privacy_settings (
    user_id              uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    ai_consent_at        timestamptz,
    nominee_name         text,
    nominee_relationship text,
    nominee_contact      text,
    updated_at           timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT user_privacy_settings_nominee_all_or_none CHECK (
        (nominee_name IS NULL AND nominee_relationship IS NULL AND nominee_contact IS NULL)
        OR (nominee_name IS NOT NULL AND nominee_relationship IS NOT NULL AND nominee_contact IS NOT NULL)
    )
);
