import "server-only";
import { apiGet } from "@/lib/server/api";

// GitLab planning & tasks (Auto Expand Board) — payload shapes served by
// GET /api/gitlab/planning/{board,issues}.

export type AeTone = "blue" | "emerald" | "purple" | "rose" | "amber" | "slate";

export interface AePerson {
  name: string;
  initial: string;
}

export interface AeTaskChip {
  id: string;
  title: string;
  dot: AeTone;
}

export interface AeQuadrant {
  key: "plan" | "do_now" | "park" | "eliminate";
  title: string;
  subtitle: string;
  tone: AeTone;
  tasks: AeTaskChip[];
}

export interface AeChangeLogEntry {
  id: string;
  time: string;
  kind: "added" | "moved" | "updated";
  message: string;
  actor: string;
}

export interface AeCountedTab {
  label: string;
  count?: number;
}

export interface AeSubtask {
  id: string;
  label: string;
  checked: boolean;
  meta?: string;
  meta_kind?: "active";
}

export interface AeStep {
  id: string;
  title: string;
  description: string;
  estimate: string;
  sub_tabs: AeCountedTab[];
  subtasks: AeSubtask[];
  file: { name: string; markdown: string } | null;
}

export interface AeTaskDetail {
  id: string;
  title: string;
  dot: AeTone;
  status: string;
  due: string;
  assignee: AePerson;
  description: string;
  tabs: AeCountedTab[];
  steps: AeStep[];
}

export interface AeBoard {
  user: AePerson & { workspace: string };
  title: string;
  subtitle: string;
  quadrants: AeQuadrant[];
  ai_placeholder: string;
  ai_suggestions: string[];
  change_log: AeChangeLogEntry[];
  task: AeTaskDetail;
}

// ── Issues (GitLab view) ────────────────────────────────────────────────────

/** Material-style tone keys used by the issues view (see auto-expand.css). */
export type AeMTone =
  | "primary" | "primary-soft" | "secondary" | "secondary-soft" | "tertiary"
  | "error" | "neutral" | "muted" | "outline";

export type AeQuadrantKey = AeQuadrant["key"];

export type AeStatusIcon =
  | "critical" | "in_progress" | "open" | "urgent" | "ready" | "parked" | "scheduled" | "eliminate";

export interface AeIssueStep {
  id: string;
  label: string;
  checked: boolean;
  note: string;
  note_icon: "done" | "progress" | "pending";
}

export interface AeComment {
  id: string;
  author: string;
  initial: string;
  tone: AeMTone;
  time: string;
  body: string;
}

export interface AeIssueDetail {
  markdown: string;
  steps: AeIssueStep[];
  branch: string;
  merge_request: string;
  discussion: AeComment[];
  activity: { id: string; time: string; text: string }[];
}

export interface AeIssue {
  id: number;
  title: string;
  status: string;
  status_icon: AeStatusIcon;
  status_title: string;
  quadrant: AeQuadrantKey;
  labels: { text: string; tone: AeMTone }[];
  opened: string;
  opened_short: string;
  author: string | null;
  meta: { text: string; icon?: "flag" | "check"; tone?: AeMTone }[];
  steps_done: number;
  steps_total: number;
  progress_tone: AeMTone;
  estimate: string;
  estimate_title: string;
  comments: number;
  files: number;
  assignee: (AePerson & { handle: string; tone: AeMTone }) | null;
  milestone: string;
  due: string;
  selected: boolean;
  detail: AeIssueDetail | null;
}

export interface AeIssuesPage {
  open_count_label: string;
  sync_label: string;
  tabs: { key: string; label: string; count: number }[];
  filters: { key: string; value: string; tone: AeMTone }[];
  sort_options: string[];
  quick_filters: { label: string; dot?: AeMTone }[];
  issues: AeIssue[];
  pagination: { from: number; to: number; total: number; pages: string[]; current: string };
}

export function getPlanningBoard(): Promise<AeBoard> {
  return apiGet<AeBoard>("/api/gitlab/planning/board");
}

export function getPlanningIssues(): Promise<AeIssuesPage> {
  return apiGet<AeIssuesPage>("/api/gitlab/planning/issues");
}
