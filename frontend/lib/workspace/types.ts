// Mirrors backend/internal/workspace/models.go (Project Workspace). Lead-owned:
// feature agents import from here and never redeclare these shapes.

export type ProjectStatus =
  | "draft"
  | "recruiting"
  | "active"
  | "paused"
  | "completed"
  | "cancelled"
  | "archived";

export type BriefStatus = "raw" | "clarifying" | "agreed";
export type ProjectRole = "owner" | "manager" | "member" | "viewer";
export type MemberStatus = "invited" | "active" | "left" | "removed";
type TrackMemberStatus = "pending" | "approved";
export type InterestStatus = "new" | "accepted" | "rejected" | "invite_expired" | "joined";

export const PROJECT_ROLE_RANK: Record<ProjectRole, number> = {
  viewer: 1,
  member: 2,
  manager: 3,
  owner: 4,
};

// Legal lifecycle edges — same table as statemachine.go ProjectStatusMachine.
export const PROJECT_STATUS_NEXT: Record<ProjectStatus, ProjectStatus[]> = {
  draft: ["recruiting", "cancelled"],
  recruiting: ["active", "cancelled"],
  active: ["paused", "completed", "cancelled"],
  paused: ["active", "cancelled"],
  completed: ["archived"],
  cancelled: ["archived"],
  archived: [],
};

interface HealthThresholds {
  s1_open_hours: number;
  forecast_red_pct: number;
  blocked_red_pct: number;
  review_wait_days: number;
  reopen_yellow_pct: number;
}

export interface Project {
  id: string;
  org_id: string;
  title: string;
  requirement: string;
  requirement_version: number;
  skills: string[];
  team_size_min: number;
  team_size_max: number;
  interest_deadline: string | null;
  key_prefix: string;
  project_status: ProjectStatus;
  brief_status: BriefStatus;
  share_token?: string;
  accepting_interests: boolean;
  brief_wiki_page_id: string | null;
  team_id: string | null;
  gitlab_enabled: boolean;
  sprints_enabled: boolean;
  wip_limit: number;
  item_seq: number;
  health_thresholds: HealthThresholds;
  activated_at: string | null;
  brief_agreed_at: string | null;
  completed_at: string | null;
  feedback_closes_at: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface ProjectSummary {
  id: string;
  title: string;
  key_prefix: string;
  project_status: ProjectStatus;
  brief_status: BriefStatus;
  my_role: ProjectRole | "";
  member_count: number;
  team_size_max: number;
  created_at: string;
}

export interface ProjectDetail extends Project {
  my_role: ProjectRole;
  is_overseer: boolean;
  my_track_ids: string[];
  led_track_ids: string[];
  seats_used: number;
  wiki_space_id: string | null;
  wiki_space_slug: string | null;
  onboarding_done: boolean;
}

export type PublicClosedReason = "deadline_passed" | "seats_full" | "not_accepting";

export interface PublicProject {
  title: string;
  requirement: string;
  skills: string[];
  interest_deadline: string | null;
  team_size_min: number;
  team_size_max: number;
  seats_left: number;
  open: boolean;
  closed_reason?: PublicClosedReason;
  org_name: string;
}

export interface Member {
  project_id: string;
  user_id: string;
  name: string;
  email?: string;
  avatar_url: string | null;
  role: ProjectRole;
  status: MemberStatus;
  added_by: string | null;
  joined_at: string;
  left_at: string | null;
  track_ids: string[];
  onboarding_pct: number;
}

interface TrackMember {
  user_id: string;
  name: string;
  status: TrackMemberStatus;
  approved_by: string | null;
}

export interface Track {
  id: string;
  project_id: string;
  name: string;
  lead_user_id: string | null;
  lead_name: string | null;
  created_at: string;
  members: TrackMember[];
}

export interface Interest {
  id: string;
  project_id: string;
  name: string;
  email: string;
  skills: string[];
  portfolio_url: string | null;
  message: string | null;
  status: InterestStatus;
  invite_id: string | null;
  user_id: string | null;
  ai_score: number | null;
  ai_rationale: string | null;
  ai_scored_at: string | null;
  reviewed_by: string | null;
  reviewed_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface ReviewInterestResult {
  interest: Interest;
  outcome: "invited" | "member_invited" | "rejected";
}

interface RequirementVersion {
  version: number;
  raw_requirement: string;
  created_by: string | null;
  created_at: string;
}

export interface RequirementView {
  requirement: string;
  requirement_version: number;
  brief_status: BriefStatus;
  versions: RequirementVersion[];
}

export interface OnboardingStep {
  id: string;
  project_id: string;
  title: string;
  wiki_page_id: string | null;
  required: boolean;
  position: number;
  done_at: string | null;
  created_at: string;
}

export interface Page<T> {
  items: T[];
  next_cursor?: string;
}

// ─── Request bodies ───────────────────────────────────────────────────────────

export interface CreateProjectInput {
  title: string;
  requirement: string;
  skills: string[];
  team_size_min: number;
  team_size_max: number;
  interest_deadline?: string | null;
  key_prefix: string;
  gitlab_enabled?: boolean;
  sprints_enabled?: boolean;
}

export interface UpdateProjectInput {
  title?: string;
  skills?: string[];
  team_size_min?: number;
  team_size_max?: number;
  interest_deadline?: string | null;
  clear_interest_deadline?: boolean;
  key_prefix?: string;
  accepting_interests?: boolean;
  gitlab_enabled?: boolean;
  sprints_enabled?: boolean;
  wip_limit?: number;
  health_thresholds?: HealthThresholds;
}

export interface SubmitInterestInput {
  name: string;
  email: string;
  skills: string[];
  portfolio_url: string;
  message: string;
  website: string; // honeypot — always sent empty by the real form
}

// ─── Phase 2: work items (models_items.go) ────────────────────────────────────

export type ItemType = "epic" | "feature" | "task" | "bug" | "subtask";
export type ItemStatus =
  | "todo"
  | "in_progress"
  | "in_review"
  | "testing"
  | "done"
  | "blocked"
  | "reopened"
  | "wont_do";
export type ItemPriority = "low" | "medium" | "high" | "urgent";
export type BugSeverity = "S1" | "S2" | "S3" | "S4";
export type DocStatus = "draft" | "in_review" | "changes_requested" | "approved";
export type AssigneeRole = "owner" | "developer" | "reviewer" | "tester";
export type LinkKind = "blocks" | "relates" | "duplicates";

// Same edges as statemachine.go WorkItemStatusMachine (task/bug/subtask only).
export const ITEM_STATUS_NEXT: Record<ItemStatus, ItemStatus[]> = {
  todo: ["in_progress", "blocked", "wont_do"],
  in_progress: ["in_review", "blocked", "wont_do"],
  in_review: ["testing", "in_progress", "blocked", "wont_do"],
  testing: ["done", "reopened", "blocked"],
  blocked: ["todo", "in_progress", "in_review", "testing", "wont_do"],
  done: ["reopened"],
  reopened: ["in_progress"],
  wont_do: [],
};

// Same table as statemachine.go HierarchyRules ("" = project root).
export const ITEM_CHILD_TYPES: Record<ItemType | "", ItemType[]> = {
  "": ["epic", "bug"],
  epic: ["feature", "bug"],
  feature: ["task", "bug"],
  task: ["subtask"],
  bug: ["subtask"],
  subtask: [],
};

export interface Assignee {
  user_id: string;
  name: string;
  role: AssigneeRole;
  assigned_by: string | null;
  assigned_at: string;
}

export interface WorkItem {
  id: string;
  project_id: string;
  key: string;
  key_num: number;
  type: ItemType;
  parent_id: string | null;
  epic_id: string | null;
  feature_id: string | null;
  track_id: string | null;
  release_id: string | null;
  sprint_id: string | null;
  title: string;
  description: string | null;
  status: ItemStatus;
  priority: ItemPriority;
  severity: BugSeverity | null;
  is_regression: boolean;
  estimate_minutes: number | null;
  doc_wiki_page_id: string | null;
  doc_status: DocStatus | null;
  approved_doc_version: number | null;
  spec_changed_at: string | null;
  blocked_reason: string | null;
  reopen_count: number;
  version: number;
  due_at: string | null;
  created_by: string | null;
  archived_at: string | null;
  created_at: string;
  updated_at: string;
  assignees: Assignee[];
}

export interface ItemRef {
  id: string;
  key: string;
  type: ItemType;
  title: string;
  status: ItemStatus;
}

export interface ItemLink {
  kind: LinkKind;
  direction: "outgoing" | "incoming";
  other: ItemRef;
  created_by: string | null;
  created_at: string;
}

export interface ItemEvent {
  id: number;
  item_id: string;
  actor_id: string | null;
  actor_name: string;
  source: "user" | "gitlab" | "system";
  kind: string;
  field: string | null;
  from_value: string | null;
  to_value: string | null;
  reason: string | null;
  created_at: string;
}

export interface ItemDetail extends WorkItem {
  parent: ItemRef | null;
  children: ItemRef[];
  links: ItemLink[];
  legal_transitions: ItemStatus[];
  locked_transitions: Partial<Record<ItemStatus, string>>;
  can_edit: boolean;
  can_delete: boolean;
}

export interface SimilarItem {
  id: string;
  key: string;
  title: string;
  type: ItemType;
  status: ItemStatus;
  similarity: number;
}

export interface CreateWorkItemInput {
  type: ItemType;
  parent_id?: string | null;
  track_id?: string | null;
  title: string;
  description?: string | null;
  priority: ItemPriority;
  severity?: BugSeverity | null;
  estimate_minutes?: number | null;
  due_at?: string | null;
}

export interface CreateWorkItemResult {
  item: WorkItem;
  similar: SimilarItem[];
}

export interface UpdateWorkItemInput {
  version: number;
  title?: string;
  description?: string;
  priority?: ItemPriority;
  severity?: BugSeverity;
  is_regression?: boolean;
  estimate_minutes?: number;
  clear_estimate?: boolean;
  due_at?: string;
  clear_due_at?: boolean;
  track_id?: string;
  clear_track?: boolean;
}

export interface TransitionInput {
  version: number;
  to: ItemStatus;
  reason?: string;
  blocker_item_id?: string;
}

export interface AssigneeInput {
  user_id: string;
  role: AssigneeRole;
}

// ─── Phase 3: clarification, brief, doc gate, triage, meetings (models_phase3.go) ─

export type MeetingKind = "kickoff" | "sprint_planning" | "standup" | "design_review" | "retro" | "demo";
export type ReviewVerdict = "approved" | "changes_requested" | "commented";
export type TriageDecision = "duplicate" | "not_a_bug" | "confirmed";

export interface RequirementQuestion {
  id: string;
  requirement_version: number;
  asked_by: string | null;
  asker_name: string;
  question: string;
  answer: string | null;
  answered_by: string | null;
  answered_at: string | null;
  is_assumption: boolean;
  created_at: string;
  updated_at: string;
  comment_count: number;
}

export interface AskQuestionResult {
  question: RequirementQuestion;
  duplicate: boolean;
}

export interface RequirementGaps {
  gaps: string[];
}

export interface BriefApproval {
  approver_id: string;
  approver_name: string;
  approver_role: "owner" | "manager" | "track_lead";
  wiki_version: number;
  created_at: string;
}

export interface BriefView {
  brief_status: BriefStatus;
  requirement_version: number;
  page_id: string | null;
  page_slug: string | null;
  page_version: number;
  approvals: BriefApproval[];
  can_approve: boolean;
  approve_blocker?: string;
}

interface ItemReview {
  id: string;
  item_id: string;
  reviewer_id: string | null;
  reviewer_name: string;
  target: "doc" | "code";
  verdict: ReviewVerdict;
  comment: string | null;
  wiki_version: number | null;
  merge_request_id: string | null;
  created_at: string;
}

export interface DocView {
  item_id: string;
  doc_status: DocStatus | null;
  page_id: string | null;
  page_slug: string | null;
  space_slug: string | null;
  page_version: number;
  approved_doc_version: number | null;
  changed_since_approval: boolean;
  reviews: ItemReview[];
  reviewers: Assignee[];
}

export interface TriageBugInput {
  decision: TriageDecision;
  severity?: BugSeverity;
  duplicate_of_id?: string;
  reason?: string;
  owner_user_id?: string;
  is_regression?: boolean;
  parent_id?: string;
}

export interface Meeting {
  calendar_event_id: string;
  kind: MeetingKind;
  title: string;
  starts_at: string;
  ends_at: string | null;
  recurrence_rule: string | null;
  meeting_url: string | null;
  item_id: string | null;
  notes_wiki_page_id: string | null;
  created_by: string | null;
  created_at: string;
}

export interface ScheduleMeetingInput {
  kind: MeetingKind;
  title: string;
  starts_at: string;
  ends_at?: string | null;
  recurrence_rule?: string | null;
  meeting_url?: string | null;
  item_id?: string | null;
  attendee_ids: string[];
}

export interface Standup {
  user_id: string;
  name: string;
  standup_on: string;
  yesterday: string;
  today: string;
  blockers: string | null;
  blocker_keys: ItemRef[];
  updated_at: string;
}

// ─── Phase 4: GitLab linking, time logs, dashboard (models_phase4.go) ─────────

type GitlabLinkKind = "branch" | "mr" | "commit";
type GitlabSyncStatus = "synced" | "pending" | "failed";
type HealthColor = "green" | "yellow" | "red";

export interface GitlabLink {
  id: string;
  kind: GitlabLinkKind;
  ref: string;
  sync_status: GitlabSyncStatus;
  mr_title: string | null;
  mr_state: string | null;
  mr_web_url: string | null;
  pipeline_status: string | null;
  additions: number | null;
  deletions: number | null;
  first_seen_at: string;
  updated_at: string;
  merged_at: string | null;
}

export interface TimeLog {
  id: string;
  item_id: string;
  item_key: string;
  user_id: string | null;
  user_name: string;
  minutes: number;
  note: string | null;
  logged_on: string;
  created_at: string;
  editable: boolean;
}

export interface TimeLogInput {
  minutes: number;
  note?: string | null;
  logged_on: string;
}

interface PercentileStat {
  count: number;
  median_hours: number | null;
  p85_hours: number | null;
}

export interface PersonRef {
  user_id: string;
  name: string;
}

export interface AttentionItem {
  item: ItemRef;
  detail: string;
  since: string | null;
}

interface AttentionPerson {
  person: PersonRef;
  detail: string;
}

interface AttentionTrack {
  track_id: string;
  name: string;
}

export interface NeedsAttention {
  blocked_items: AttentionItem[];
  overdue_items: AttentionItem[];
  stale_reviews: AttentionItem[];
  open_s1_s2_bugs: AttentionItem[];
  stuck_onboarding: AttentionPerson[];
  inactive_members: AttentionPerson[];
  leaderless_tracks: AttentionTrack[];
  standup_blockers: ItemRef[];
}

export interface DayPoint {
  day: string;
  open: number;
  done: number;
  added: number;
}

interface WeekPoint {
  week: string;
  count: number;
  fixed?: number;
}

interface ScopeChurn {
  added_after_start: number;
  removed_after_start: number;
  change_requests: number;
  brief_versions_after_agreed: number;
}

interface RequirementClarity {
  asked: number;
  answered: number;
  assumptions: number;
  median_answer_hours: number | null;
  days_active_to_agreed: number | null;
}

interface Forecast {
  remaining: number;
  weekly_throughput: number;
  projected_finish: string | null;
  target: string | null;
  over_target_pct: number | null;
}

export interface Delivery {
  progress_pct: number;
  burndown: DayPoint[];
  throughput: WeekPoint[];
  lead_time: PercentileStat;
  cycle_time: PercentileStat;
  stage_time: Record<string, PercentileStat>;
  blocked_hours: number;
  top_blockers: AttentionItem[];
  scope_churn: ScopeChurn;
  requirement_clarity: RequirementClarity;
  sprint_commitment_pct: number | null;
  forecast: Forecast;
  doc_turnaround: PercentileStat;
  doc_review_rounds: number;
}

interface SeverityCount {
  severity: BugSeverity;
  open: number;
  oldest_age_hours: number;
}

interface FeatureDensity {
  feature: ItemRef;
  bugs: number;
  tasks: number;
}

export interface Quality {
  bugs_by_severity: SeverityCount[];
  bug_inflow_vs_fix: WeekPoint[];
  reopen_rate_pct: number;
  escaped_bugs: number;
  bug_density: FeatureDensity[];
  ci_pass_rate_pct: number | null;
  mr_review_rounds: PercentileStat;
  mr_size_median: number | null;
  large_mrs: number;
  test_coverage_pct: number;
}

export interface PersonMetrics {
  person: PersonRef;
  role: ProjectRole;
  load_by_role: Record<string, number>;
  wip: number;
  wip_limit: number;
  completed_owned: number;
  reviews_done: number;
  tests_done: number;
  review_response_hours: number | null;
  minutes_logged: number;
  commits: number;
  mrs_opened: number;
  mrs_merged: number;
  estimate_accuracy: number | null;
  reopens_caused: number;
  attendance_pct: number | null;
  standups_posted: number;
  onboarding_pct: number;
  last_active: string | null;
}

export interface PlanTreeNode {
  item: ItemRef;
  progress_pct: number;
  doc_status: DocStatus | null;
  release_id: string | null;
  owner: PersonRef | null;
  at_risk: boolean;
  children: PlanTreeNode[];
}

export interface TrackMetrics {
  track_id: string;
  name: string;
  lead: PersonRef | null;
  members: number;
  open: number;
  done: number;
  throughput: number;
  cycle_time: PercentileStat;
  bugs: number;
  wip: number;
  capacity: number;
  features_awaiting_doc: number;
  cross_track_blockers: number;
}

export interface HealthReport {
  color: HealthColor;
  reasons: string[];
}

export interface DashboardHeader {
  status: ProjectStatus;
  days_left: number | null;
  release_target: string | null;
  health: HealthReport;
  from: string;
  to: string;
}

export interface Dashboard {
  header: DashboardHeader;
  needs_attention: NeedsAttention;
  delivery: Delivery;
  quality: Quality;
  people: PersonMetrics[];
  plan_tree: PlanTreeNode[];
  tracks: TrackMetrics[];
  release: ReleaseMetrics | null;
  ai_summary: WeeklySummary | null;
}

export interface DashboardFilter {
  from?: string;
  to?: string;
  track?: string;
  user?: string;
  release?: string;
}

// ─── Phase 5: releases, sprints, completion, feedback, AI (models_phase5.go) ──

export type ReleaseStatus = "planned" | "frozen" | "released";
export type SprintStatus = "planned" | "active" | "completed";


export interface Release {
  id: string;
  version: string;
  status: ReleaseStatus;
  target_at: string | null;
  frozen_at: string | null;
  released_at: string | null;
  created_by: string | null;
  created_at: string;
  features_done: number;
  features_total: number;
  open_bugs: number;
}

export interface CreateReleaseInput {
  version: string;
  target_at?: string | null;
}

export interface UpdateReleaseInput {
  version?: string;
  target_at?: string | null;
  clear_target?: boolean;
  status?: ReleaseStatus;
}

export interface SetItemReleaseInput {
  version: number;
  release_id: string | null;
}

export interface SetItemSprintInput {
  version: number;
  sprint_id: string | null;
}

interface ReleaseNoteItem {
  item: ItemRef;
  doc_version: number | null;
}

export interface ReleaseNotes {
  release_id: string;
  items: ReleaseNoteItem[];
  polished: string | null;
}

export interface Sprint {
  id: string;
  name: string;
  starts_on: string;
  ends_on: string;
  status: SprintStatus;
  created_at: string;
  committed: number;
  done: number;
  burndown?: DayPoint[];
}

export interface CreateSprintInput {
  name: string;
  starts_on: string;
  ends_on: string;
}

export type UnfinishedChoice = "carry_over" | "backlog";

export interface CloseSprintInput {
  unfinished: UnfinishedChoice;
  next_sprint_id?: string | null;
}

export interface PeerFeedbackInput {
  to_user_id: string;
  rating: number;
  comment?: string | null;
}

export interface PeerFeedbackRow {
  from_user: PersonRef;
  to_user: PersonRef;
  rating: number;
  comment: string | null;
  created_at: string;
}

interface MyFeedback {
  available: boolean;
  average?: number;
  comments?: string[];
}

export interface FeedbackView {
  window_closes_at: string | null;
  open: boolean;
  rateable: PersonRef[];
  given: PeerFeedbackRow[];
  mine: MyFeedback;
  all?: PeerFeedbackRow[];
}

export interface MemberReport {
  person: PersonRef;
  role: ProjectRole;
  items_owned: number;
  items_done_owned: number;
  items_reviewed: number;
  items_tested: number;
  reopens_caused: number;
  doc_approvals: number;
  mrs_opened: number;
  mrs_merged: number;
  review_comments: number;
  minutes_logged: number;
  meetings_attended: number;
  meetings_missed: number;
  standups_posted: number;
  peer_rating: number | null;
  showcase_opt_in: boolean;
  certificate_id: string | null;
}

export interface IssueCertificateInput {
  user_id: string;
  experience_note: string;
}

export interface SuggestedItem {
  type: ItemType;
  title: string;
  description: string;
}

export interface ItemSuggestions {
  items: SuggestedItem[];
  cached_at: string;
}

export interface AssigneeSuggestion {
  person: PersonRef;
  wip: number;
  reason: string;
}

export interface LateExplanation {
  explanation: string;
  cached_at: string;
}

export interface ChangeImpact {
  affected_item_ids: string[];
  summary: string;
  cached_at: string;
}

export interface WeeklySummary {
  week: string;
  shipped: string[];
  risks: string[];
  needs_help: string[];
  created_at: string;
}

export interface ReleaseMetrics {
  release_id: string;
  version: string;
  status: ReleaseStatus;
  features_done: number;
  features_total: number;
  open_bugs_by_severity: Record<string, number>;
  days_to_target: number | null;
  forecast_finish: string | null;
  scope_added_after_freeze: number;
  docs_not_approved: number;
  readiness: Record<string, boolean>;
}

export type ExportKind = "items" | "time_logs" | "members";
