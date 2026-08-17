// Mirrors backend/internal/useroverview.Overview and the RBAC admin types it
// sits alongside (roles/permissions/audit) — one file since every tab
// component on this page reads from this same shape.

export interface CourseSummary {
  id: string;
  title: string;
  slug: string;
  cover_url: string | null;
  difficulty: string;
  status: string;
}

export interface EnrollmentProgress {
  completed: number;
  total: number;
  pct: number;
  last_activity_at: string | null;
}

export interface Enrollment {
  id: string;
  course_id: string;
  batch_id: string | null;
  enrolled_at: string;
  completed_at: string | null;
  course: CourseSummary;
  progress: EnrollmentProgress;
}

export interface ActivityEntry {
  key: string;
  kind: string;
  occurred_at: string;
  day: string;
  title: string;
  summary?: string;
  ref_id?: string;
  ref_type?: string;
  ref_slug?: string;
}

export interface UserSheetSummary {
  id: string;
  name: string;
  slug: string;
  category: string | null;
  is_system: boolean;
  item_count: number;
  role: string;
  solved_count: number;
}

export interface MistakeEntry {
  id: string;
  user_id: string;
  category: string;
  original_text: string;
  corrected_text?: string;
  resolved_at: string | null;
  created_at: string;
  status: string;
}

export interface MistakeCategorySummary {
  category: string;
  total: number;
  first_occurred_at: string;
  last_occurred_at: string;
  trend: "worsening" | "stable" | "improving";
}

export interface Habit {
  id: string;
  name: string;
  cadence: string;
  type: string;
  color: string;
  icon: string;
  tags: string[];
  target_count: number;
  weekdays: number[];
}

export interface HabitCompletion {
  habit_id: string;
  period_start: string;
  count: number;
}

export interface HabitMonth {
  habits: Habit[];
  completions: HabitCompletion[];
}

export interface JournalEntry {
  id: string;
  entry_date: string;
  category: string;
  subcategory: string;
  title: string;
  content: string;
}

export interface UserOverview {
  enrollments: Enrollment[];
  recent_activity: ActivityEntry[];
  sheets: UserSheetSummary[];
  mistakes: MistakeEntry[];
  mistake_summary: MistakeCategorySummary[];
  habit_month: HabitMonth;
  journal_entries: JournalEntry[];
}

export interface RoleFull {
  id: string;
  name: string;
  description: string;
  is_system: boolean;
  is_active: boolean;
}

export interface PermissionMeta {
  id: string;
  code: string;
  name: string;
  module: string;
}

export interface AuditEntry {
  id: number;
  org_id: string | null;
  actor_id: string | null;
  actor_name: string | null;
  actor_email: string | null;
  action: string;
  entity_type: string | null;
  entity_id: string;
  diff: Record<string, unknown> | null;
  created_at: string;
}
