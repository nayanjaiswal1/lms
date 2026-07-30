-- ═════════════════════════════════════════════════════════════════════════
-- Migration 021 — add_interview_experiences
-- Crowd-sourced interview experience board: company/position-tagged posts,
-- multi-user continuation (entries = rounds), Q&A that can hang off a round
-- OR directly off the post (standalone questions, no narrative required),
-- unlimited-depth nested comments, and up/down voting on qna + comments.
-- Deliberately carries no org_id — unlike the rest of MindForge, this
-- content is platform-wide: a "Google Backend Engineer" thread is useful to
-- every org's students, not just one tenant's. See docs/interview-experiences.md.
-- Unrelated to interview_sessions/interview_questions (docs/interview.md,
-- the live mock-interview board) — hence the interview_exp_* prefix.
-- ═════════════════════════════════════════════════════════════════════════

CREATE TABLE public.interview_exp_posts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    author_id uuid NOT NULL,
    company text NOT NULL,
    position text NOT NULL,
    tags text[] DEFAULT '{}'::text[] NOT NULL,
    title text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT interview_exp_posts_pkey PRIMARY KEY (id),
    CONSTRAINT interview_exp_posts_author_fk FOREIGN KEY (author_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT interview_exp_posts_company_not_blank_check CHECK (btrim(company) <> ''::text),
    CONSTRAINT interview_exp_posts_position_not_blank_check CHECK (btrim(position) <> ''::text),
    CONSTRAINT interview_exp_posts_title_not_blank_check CHECK (btrim(title) <> ''::text)
);

CREATE INDEX idx_interview_exp_posts_company_position
    ON public.interview_exp_posts (company, position);
CREATE INDEX idx_interview_exp_posts_tags
    ON public.interview_exp_posts USING GIN (tags);
CREATE INDEX idx_interview_exp_posts_created
    ON public.interview_exp_posts (created_at DESC);

-- Optional round/continuation added by the original author or anyone else.
-- A post can have zero entries and just carry standalone Q&A.
CREATE TABLE public.interview_exp_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    post_id uuid NOT NULL,
    author_id uuid NOT NULL,
    round_label text NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT interview_exp_entries_pkey PRIMARY KEY (id),
    CONSTRAINT interview_exp_entries_post_fk FOREIGN KEY (post_id)
        REFERENCES public.interview_exp_posts(id) ON DELETE CASCADE,
    CONSTRAINT interview_exp_entries_author_fk FOREIGN KEY (author_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT interview_exp_entries_round_label_not_blank_check CHECK (btrim(round_label) <> ''::text)
);

CREATE INDEX idx_interview_exp_entries_post
    ON public.interview_exp_entries (post_id);

-- entry_id NULL = standalone question on the post, not tied to a specific round.
CREATE TABLE public.interview_exp_qna (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    post_id uuid NOT NULL,
    entry_id uuid,
    author_id uuid NOT NULL,
    question text NOT NULL,
    answer text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT interview_exp_qna_pkey PRIMARY KEY (id),
    CONSTRAINT interview_exp_qna_post_fk FOREIGN KEY (post_id)
        REFERENCES public.interview_exp_posts(id) ON DELETE CASCADE,
    CONSTRAINT interview_exp_qna_entry_fk FOREIGN KEY (entry_id)
        REFERENCES public.interview_exp_entries(id) ON DELETE CASCADE,
    CONSTRAINT interview_exp_qna_author_fk FOREIGN KEY (author_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT interview_exp_qna_question_not_blank_check CHECK (btrim(question) <> ''::text)
);

CREATE INDEX idx_interview_exp_qna_post
    ON public.interview_exp_qna (post_id);
CREATE INDEX idx_interview_exp_qna_entry
    ON public.interview_exp_qna (entry_id) WHERE entry_id IS NOT NULL;

-- Unlimited-depth nesting via self-reference (unlike wiki_comments, which
-- caps at one level — this feature was explicitly asked to nest further).
CREATE TABLE public.interview_exp_comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    qna_id uuid NOT NULL,
    parent_id uuid,
    author_id uuid NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT interview_exp_comments_pkey PRIMARY KEY (id),
    CONSTRAINT interview_exp_comments_qna_fk FOREIGN KEY (qna_id)
        REFERENCES public.interview_exp_qna(id) ON DELETE CASCADE,
    CONSTRAINT interview_exp_comments_parent_fk FOREIGN KEY (parent_id)
        REFERENCES public.interview_exp_comments(id) ON DELETE CASCADE,
    CONSTRAINT interview_exp_comments_author_fk FOREIGN KEY (author_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT interview_exp_comments_content_not_blank_check CHECK (btrim(content) <> ''::text)
);

CREATE INDEX idx_interview_exp_comments_qna_parent
    ON public.interview_exp_comments (qna_id, parent_id);

-- One vote per user per target; value 1/-1, upsert on the unique key (no
-- row for "no vote" — the vote endpoint deletes the row to clear a vote
-- rather than storing 0).
CREATE TABLE public.interview_exp_votes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    target_type text NOT NULL,
    target_id uuid NOT NULL,
    value smallint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT interview_exp_votes_pkey PRIMARY KEY (id),
    CONSTRAINT interview_exp_votes_user_fk FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT interview_exp_votes_target_type_check CHECK (target_type = ANY (ARRAY['qna'::text, 'comment'::text])),
    CONSTRAINT interview_exp_votes_value_check CHECK (value = ANY (ARRAY[-1, 1])),
    CONSTRAINT interview_exp_votes_unique UNIQUE (user_id, target_type, target_id)
);

CREATE INDEX idx_interview_exp_votes_target
    ON public.interview_exp_votes (target_type, target_id);

-- RBAC: any authenticated member can post/vote/comment (docs/rbac.md §11 recipe).
INSERT INTO public.permissions (code, name, description, module)
VALUES ('content.interview_exp', 'Interview Experiences', 'Post, answer, and vote on interview experiences', 'content')
ON CONFLICT (code) DO NOTHING;

-- role_id '11111111-1111-1111-1111-000000000002' = system 'member' role (001_baseline.sql).
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT '11111111-1111-1111-1111-000000000002'::uuid, id FROM public.permissions WHERE code = 'content.interview_exp'
ON CONFLICT DO NOTHING;
