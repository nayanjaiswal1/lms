-- ═════════════════════════════════════════════════════════════════════════
-- Migration 007 — mentor_conversations
-- ═════════════════════════════════════════════════════════════════════════
-- A ticket-independent 1:1 messaging thread between a student and any
-- mentor in the org — deliberately separate from mentor_tickets/
-- mentor_chat_messages, which represent a course-enrollment-scoped
-- mentorship assignment. This lets a student message a mentor they browse
-- to but aren't (yet, or ever) assigned to, without changing the meaning
-- or access rules of the existing ticket chat.

CREATE TABLE public.mentor_conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    student_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    mentor_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mentor_conversations_org_student_mentor_key UNIQUE (org_id, student_id, mentor_id),
    CONSTRAINT mentor_conversations_distinct_parties_check CHECK (student_id <> mentor_id)
);

CREATE INDEX idx_mentor_conversations_student ON public.mentor_conversations (org_id, student_id);
CREATE INDEX idx_mentor_conversations_mentor ON public.mentor_conversations (org_id, mentor_id);

CREATE TABLE public.mentor_direct_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    conversation_id uuid NOT NULL REFERENCES public.mentor_conversations(id) ON DELETE CASCADE,
    sender_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    body text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mentor_direct_messages_body_check CHECK (((length(body) >= 1) AND (length(body) <= 4000)))
);

CREATE INDEX idx_mentor_direct_messages_conversation ON public.mentor_direct_messages (conversation_id, created_at);
