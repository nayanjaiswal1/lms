// Shared types for the Assessment & Evaluation domain.
// These mirror the Go backend response shapes. They are the single source of
// truth for assessment data on the frontend.

export interface ProctoringConfig {
  require_fullscreen: boolean;
  fullscreen_exit_action: "pause" | "continue" | "auto_submit";
  block_copy_paste: boolean;
  block_right_click: boolean;
  block_devtools: boolean;
  max_tab_switches: number;
  max_focus_loss: number;
  auto_submit_on_violation: boolean;
  heartbeat_seconds: number;
  require_camera: boolean;
  allow_secondary_camera: boolean;
}

export interface Assessment {
  id: string;
  title: string;
  slug: string;
  description: string | null;
  type: "mcq" | "coding" | "mixed";
  status: "draft" | "published" | "scheduled" | "active" | "completed" | "archived";
  mock_mode: boolean;
  parent_type: string;
  parent_id: string | null;
  duration_minutes: number;
  pass_percentage: number;
  max_attempts: number;
  total_points: number;
  shuffle_questions: boolean;
  shuffle_options: boolean;
  allow_backtrack: boolean;
  show_results: boolean;
  starts_at: string | null;
  ends_at: string | null;
  proctoring: ProctoringConfig;
  question_count: number;
  short_code?: string | null;
  created_at: string;
}

export interface AssignedAssessment extends Assessment {
  attempts_used: number;
  best_percentage: number | null;
  best_passed: boolean | null;
  active_attempt_id: string | null;
  evaluating_attempt_id: string | null;
}

export interface Question {
  id: string;
  type: "mcq" | "coding" | "subjective";
  title: string;
  difficulty: string;
  default_points: number;
  tags: string[];
  status: string;
  current_version: number;
  category_id: string | null;
  content?: unknown;
}

export interface StudentMCQContent {
  prompt: string;
  multiple: boolean;
  options: { id: string; text: string }[];
}

export interface StudentCodingContent {
  prompt: string;
  languages: string[];
  starter_code: Record<string, string>;
  time_limit_ms: number;
  memory_limit_kb: number;
  sample_cases: { stdin: string; expected: string }[];
  hidden_count: number;
}

export interface StudentSubjectiveContent {
  prompt: string;
}

export interface StudentMCQQuestion {
  assessment_question_id: string;
  question_id: string;
  type: "mcq";
  title: string;
  difficulty: string;
  position: number;
  points: number;
  content: StudentMCQContent;
}

export interface StudentCodingQuestion {
  assessment_question_id: string;
  question_id: string;
  type: "coding";
  title: string;
  difficulty: string;
  position: number;
  points: number;
  content: StudentCodingContent;
}

export interface StudentSubjectiveQuestion {
  assessment_question_id: string;
  question_id: string;
  type: "subjective";
  title: string;
  difficulty: string;
  position: number;
  points: number;
  content: StudentSubjectiveContent;
}

export type StudentQuestion = StudentMCQQuestion | StudentCodingQuestion | StudentSubjectiveQuestion;

export function isMCQQuestion(q: StudentQuestion): q is StudentMCQQuestion {
  return q.type === "mcq";
}

export function isSubjectiveQuestion(q: StudentQuestion): q is StudentSubjectiveQuestion {
  return q.type === "subjective";
}

export interface Attempt {
  id: string;
  assessment_id: string;
  user_id: string;
  org_id: string;
  status: "created" | "in_progress" | "submitted" | "evaluating" | "evaluated" | "eval_failed" | "expired";
  attempt_number: number;
  started_at: string | null;
  submitted_at: string | null;
  expires_at: string | null;
  duration_seconds: number;
  score: number | null;
  max_score: number | null;
  percentage: number | null;
  passed: boolean | null;
  auto_submitted: boolean;
  reward_result?: import("@/lib/server/rewards").AwardResult;
}

export interface AttemptMeta {
  title: string;
  duration_minutes: number;
  allow_backtrack: boolean;
  mock_mode: boolean;
  total_points: number;
  pass_percentage: number;
}

export interface AttemptPayload {
  attempt: Attempt;
  questions: StudentQuestion[];
  proctoring: ProctoringConfig;
  meta: AttemptMeta;
}

// ─── Evaluation types ─────────────────────────────────────────────────────────

export interface EvaluationStatus {
  attempt_id: string;
  status: string;
  has_result: boolean;
}

export interface EvaluationRow {
  id: string;
  question_id: string | null;
  scope: "question" | "overall";
  score_technical_accuracy: number | null;
  score_completeness: number | null;
  score_communication: number | null;
  score_clarity: number | null;
  score_structure: number | null;
  score_confidence: number | null;
  score_seniority_alignment: number | null;
  composite_score: number | null;
  readiness_score: number | null;
  strengths: string[];
  weaknesses: string[];
  missing_concepts: string[];
  incorrect_concepts: string[];
  improvements: string[];
  better_answer: string | null;
  reference_comparison: string | null;
  review_required: boolean;
  ai_model: string | null;
  created_at: string;
}

export interface FullEvaluation {
  status: string;
  overall: EvaluationRow | null;
  per_question: EvaluationRow[];
}

// ─── Progress & skills ────────────────────────────────────────────────────────

export interface SkillTrend {
  skill: string;
  latest_score: number;
  avg_score: number;
  attempt_count: number;
  is_weak: boolean;
  is_strong: boolean;
  last_attempt_at: string;
}

export interface StudentProgress {
  total_evaluated: number;
  latest_readiness_score: number | null;
  avg_readiness_score: number;
  skill_trends: SkillTrend[];
}

// ─── Review queue (staff) ─────────────────────────────────────────────────────

export interface ReviewQueueItem {
  attempt_id: string;
  user_id: string;
  user_name: string;
  assessment_id: string;
  assessment_title: string;
  composite_score: number | null;
  injection_score: number;
  created_at: string;
}

export interface ReviewItem {
  question_id: string;
  title: string;
  type: "mcq" | "coding";
  position: number;
  max_points: number;
  points_awarded: number;
  is_correct: boolean | null;
  answer: unknown;
  correct_answer?: { selected: string[] };
  explanation?: string;
  coding_result?: { status: string; tests_passed: number; tests_total: number };
}

export interface AssessmentAnalytics {
  assessment_id: string;
  total_attempts: number;
  evaluated: number;
  avg_percentage: number;
  pass_rate: number;
  avg_duration_sec: number;
  high_score: number;
  low_score: number;
  score_buckets: Record<string, number>;
  question_stats: {
    question_id: string;
    title: string;
    type: string;
    answered: number;
    correct_rate: number;
    avg_points: number;
  }[];
  flagged_attempts: number;
}

export interface AttemptRow {
  id: string;
  user_id: string;
  user_name: string;
  user_email: string;
  status: string;
  attempt_number: number;
  percentage: number | null;
  passed: boolean | null;
  duration_sec: number;
  flags: number;
}

export interface Batch {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  mentor_id: string | null;
  status: string;
  member_count: number;
}
