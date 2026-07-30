// Mirrors backend/internal/notifications/models.go exactly — verified
// directly against that file rather than guessed. Generic, cross-feature
// domain (bell icon in the app shell), so these types live outside
// lib/projects/ even though GitLab's checkpoint flows are its first caller.

export type NotificationPriority = "low" | "normal" | "high";

export interface Notification {
  id: string;
  org_id: string;
  user_id: string;
  type: string;
  title: string;
  body: string | null;
  link_url: string | null;
  entity_type: string | null;
  entity_id: string | null;
  actor_user_id: string | null;
  priority: NotificationPriority;
  dedupe_key: string;
  read_at: string | null;
  created_at: string;
}

// GET /api/notifications
export interface ListView {
  notifications: Notification[];
}

// GET /api/notifications/unread-count
export interface UnreadCountView {
  unread_count: number;
}
