CREATE TABLE focus_wall_categories (
    id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name       text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_focus_wall_categories_user_name
    ON focus_wall_categories (user_id, lower(name));

-- Custom categories previously lived only as free-text on notes; materialise them.
INSERT INTO focus_wall_categories (user_id, name)
SELECT DISTINCT ON (user_id, lower(category)) user_id, category
FROM focus_wall_notes
WHERE category NOT IN ('personal', 'study', 'urgent')
ORDER BY user_id, lower(category), category;
