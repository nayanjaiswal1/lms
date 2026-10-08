ALTER TABLE org_invites
    ADD COLUMN email_status text NOT NULL DEFAULT 'pending'
        CONSTRAINT org_invites_email_status_check CHECK (email_status IN ('pending', 'sent', 'failed')),
    ADD COLUMN email_error text;
