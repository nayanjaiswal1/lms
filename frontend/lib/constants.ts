// ─────────────────────────────────────────────
// App-wide constants & option lists.
// Never define these inside a component.
// Import the *_OPTIONS arrays as `options` props.
// ─────────────────────────────────────────────

import ROUTES from "@/lib/routes";


// Sidebar/mobile-nav logo click destination and post-login/app-open landing, user-configurable in Settings >
// Profile > Preferences. Mirrors backend/internal/profile/models.go's
// ValidDefaultLandingPages and the user_profiles_default_landing_page_check
// DB constraint — keep all three in sync. Restricted to routes with no
// feature/permission gate (lib/nav.ts's ALL_NAV_ITEMS) so the chosen page is
// always reachable regardless of the user's org features or RBAC permissions.
export const DEFAULT_LANDING_PAGE_OPTIONS = [
  { label: "Dashboard",    value: ROUTES.DASHBOARD },
  { label: "Learn",        value: ROUTES.LEARN },
  { label: "Calendar",     value: ROUTES.CALENDAR },
  { label: "My Mistakes",  value: ROUTES.MISTAKES },
  { label: "Last page I visited", value: ROUTES.LAST_VISITED },
] as const;

// Cookie the proxy keeps current with the last app page viewed; read by the
// ROUTES.LAST_VISITED route handler.
export const LAST_PAGE_COOKIE = "last_page";
// Epoch-ms of the last DB sync of that page; throttles the cross-device write.
export const LAST_PAGE_SYNC_COOKIE = "last_page_sync";
export const LAST_PAGE_SYNC_INTERVAL_MS = 60_000;

// ─────────────────────────────────────────────

const CONTENT_REPORT_REASON = {
  ILLEGAL:     "illegal",
  COPYRIGHT:   "copyright",
  SPAM:        "spam",
  HARASSMENT:  "harassment",
  OTHER:       "other",
} as const;

export const CONTENT_REPORT_REASON_OPTIONS = [
  { label: "Illegal content",  value: CONTENT_REPORT_REASON.ILLEGAL },
  { label: "Copyright infringement", value: CONTENT_REPORT_REASON.COPYRIGHT },
  { label: "Spam",             value: CONTENT_REPORT_REASON.SPAM },
  { label: "Harassment",       value: CONTENT_REPORT_REASON.HARASSMENT },
  { label: "Other",            value: CONTENT_REPORT_REASON.OTHER },
] as const;

const CONTENT_REPORT_STATUS = {
  PENDING:   "pending",
  REVIEWING: "reviewing",
  REMOVED:   "removed",
  DISMISSED: "dismissed",
} as const;

export const CONTENT_REPORT_STATUS_OPTIONS = [
  { label: "Pending",   value: CONTENT_REPORT_STATUS.PENDING },
  { label: "Reviewing", value: CONTENT_REPORT_STATUS.REVIEWING },
  { label: "Removed",   value: CONTENT_REPORT_STATUS.REMOVED },
  { label: "Dismissed", value: CONTENT_REPORT_STATUS.DISMISSED },
] as const;

const DIFFICULTY = {
  EASY:   "easy",
  MEDIUM: "medium",
  HARD:   "hard",
} as const;
export type Difficulty = (typeof DIFFICULTY)[keyof typeof DIFFICULTY];

export const DIFFICULTY_OPTIONS = [
  { label: "Easy",   value: DIFFICULTY.EASY },
  { label: "Medium", value: DIFFICULTY.MEDIUM },
  { label: "Hard",   value: DIFFICULTY.HARD },
] as const;

// ─────────────────────────────────────────────

const ORG_MEMBER_STATUS = {
  ACTIVE:    "active",
  SUSPENDED: "suspended",
} as const;

export const ORG_MEMBER_STATUS_OPTIONS = [
  { label: "Active",    value: ORG_MEMBER_STATUS.ACTIVE },
  { label: "Suspended", value: ORG_MEMBER_STATUS.SUSPENDED },
] as const;

// ─────────────────────────────────────────────



// ─────────────────────────────────────────────

const CODE_LANGUAGE = {
  PYTHON:     "python",
  JAVASCRIPT: "javascript",
  TYPESCRIPT: "typescript",
  GO:         "go",
  JAVA:       "java",
  CPP:        "cpp",
  RUST:       "rust",
} as const;

export const CODE_LANGUAGE_OPTIONS = [
  { label: "Python",     value: CODE_LANGUAGE.PYTHON },
  { label: "JavaScript", value: CODE_LANGUAGE.JAVASCRIPT },
  { label: "TypeScript", value: CODE_LANGUAGE.TYPESCRIPT },
  { label: "Go",         value: CODE_LANGUAGE.GO },
  { label: "Java",       value: CODE_LANGUAGE.JAVA },
  { label: "C++",        value: CODE_LANGUAGE.CPP },
  { label: "Rust",       value: CODE_LANGUAGE.RUST },
] as const;

// ─────────────────────────────────────────────



// ─────────────────────────────────────────────



// ─────────────────────────────────────────────



// ─────────────────────────────────────────────



// ─────────────────────────────────────────────



// ─────────────────────────────────────────────

const USER_ROLE = {
  STUDENT:    "student",
  INSTRUCTOR: "instructor",
  MENTOR:     "mentor",
  ORG_ADMIN:  "admin",
} as const;

export const ORG_ROLE_OPTIONS = [
  { label: "Student",    value: USER_ROLE.STUDENT },
  { label: "Instructor", value: USER_ROLE.INSTRUCTOR },
  { label: "Mentor",     value: USER_ROLE.MENTOR },
] as const;

// ─────────────────────────────────────────────
// Assessment & Evaluation domain (mirrors backend enums)
// ─────────────────────────────────────────────

export const QUESTION_TYPE = {
  MCQ:    "mcq",
  CODING: "coding",
} as const;

export const QUESTION_TYPE_OPTIONS = [
  { label: "Multiple Choice", value: QUESTION_TYPE.MCQ },
  { label: "Coding",          value: QUESTION_TYPE.CODING },
] as const;

const ASSESSMENT_DIFFICULTY = {
  BEGINNER:     "beginner",
  INTERMEDIATE: "intermediate",
  ADVANCED:     "advanced",
  EXPERT:       "expert",
} as const;

export const ASSESSMENT_DIFFICULTY_OPTIONS = [
  { label: "Beginner",     value: ASSESSMENT_DIFFICULTY.BEGINNER },
  { label: "Intermediate", value: ASSESSMENT_DIFFICULTY.INTERMEDIATE },
  { label: "Advanced",     value: ASSESSMENT_DIFFICULTY.ADVANCED },
  { label: "Expert",       value: ASSESSMENT_DIFFICULTY.EXPERT },
] as const;

// ─────────────────────────────────────────────

// Mirrors whats_new_entries_icon_check (backend/db/migrations/032_whats_new.sql)
// and AllowedIcons (backend/internal/whatsnew/models.go) — the fixed icon set
// WHATS_NEW_ICON_MAP (lib/whats-new.ts) can render, so an admin can't pick an
// icon the sidebar panel doesn't ship.
export const WHATS_NEW_ICON = {
  SPARKLES:        "sparkles",
  BOOK_OPEN_CHECK: "book-open-check",
  LIST_CHECKS:     "list-checks",
  SHIELD_CHECK:    "shield-check",
  ROCKET:          "rocket",
  MEGAPHONE:       "megaphone",
  ZAP:             "zap",
  STAR:            "star",
} as const;
export type WhatsNewIcon = (typeof WHATS_NEW_ICON)[keyof typeof WHATS_NEW_ICON];

export const WHATS_NEW_ICON_OPTIONS = [
  { label: "Sparkles",  value: WHATS_NEW_ICON.SPARKLES },
  { label: "Book",      value: WHATS_NEW_ICON.BOOK_OPEN_CHECK },
  { label: "Checklist", value: WHATS_NEW_ICON.LIST_CHECKS },
  { label: "Shield",    value: WHATS_NEW_ICON.SHIELD_CHECK },
  { label: "Rocket",    value: WHATS_NEW_ICON.ROCKET },
  { label: "Megaphone", value: WHATS_NEW_ICON.MEGAPHONE },
  { label: "Lightning", value: WHATS_NEW_ICON.ZAP },
  { label: "Star",      value: WHATS_NEW_ICON.STAR },
] as const;

const ASSESSMENT_STATUS = {
  DRAFT:     "draft",
  PUBLISHED: "published",
  SCHEDULED: "scheduled",
  ACTIVE:    "active",
  COMPLETED: "completed",
  ARCHIVED:  "archived",
} as const;

export const ASSESSMENT_STATUS_OPTIONS = [
  { label: "Draft",     value: ASSESSMENT_STATUS.DRAFT },
  { label: "Published", value: ASSESSMENT_STATUS.PUBLISHED },
  { label: "Scheduled", value: ASSESSMENT_STATUS.SCHEDULED },
  { label: "Active",    value: ASSESSMENT_STATUS.ACTIVE },
  { label: "Completed", value: ASSESSMENT_STATUS.COMPLETED },
  { label: "Archived",  value: ASSESSMENT_STATUS.ARCHIVED },
] as const;

// Subset of statuses the backend accepts on the generic manual status-move
// endpoint (POST /api/assessments/{id}/status — see the `allowed` map in
// handler_assessment.go SetAssessmentStatus). "published" and "scheduled"
// are deliberately excluded — those only happen via the dedicated /publish
// flow, never a manual status move.
export const ASSESSMENT_MANUAL_STATUS_OPTIONS = [
  { label: "Draft",     value: ASSESSMENT_STATUS.DRAFT,     description: "Unpublish — reopen for editing, hidden from students." },
  { label: "Active",    value: ASSESSMENT_STATUS.ACTIVE,    description: "Open and available for students to attempt." },
  { label: "Completed", value: ASSESSMENT_STATUS.COMPLETED, description: "Closed to new attempts, results remain visible." },
  { label: "Archived",  value: ASSESSMENT_STATUS.ARCHIVED,  description: "Hidden from active lists — for long-term storage." },
] as const;

export const ASSESSMENT_PARENT_TYPE = {
  STANDALONE: "standalone",
  COURSE:     "course",
  MODULE:     "module",
  ROADMAP:    "roadmap",
  BATCH:      "batch",
  BOOTCAMP:   "bootcamp",
  HIRING:     "hiring",
} as const;
export type AssessmentParentType = (typeof ASSESSMENT_PARENT_TYPE)[keyof typeof ASSESSMENT_PARENT_TYPE];



// ─────────────────────────────────────────────

const EXPERIENCE_LEVEL = {
  BEGINNER:     "beginner",
  INTERMEDIATE: "intermediate",
  ADVANCED:     "advanced",
} as const;

export const EXPERIENCE_LEVEL_OPTIONS = [
  { label: "Beginner",     value: EXPERIENCE_LEVEL.BEGINNER },
  { label: "Intermediate", value: EXPERIENCE_LEVEL.INTERMEDIATE },
  { label: "Advanced",     value: EXPERIENCE_LEVEL.ADVANCED },
] as const;

// ─────────────────────────────────────────────

const SKILL_LEVEL = {
  BEGINNER:     "beginner",
  INTERMEDIATE: "intermediate",
  ADVANCED:     "advanced",
} as const;
export type SkillLevel = (typeof SKILL_LEVEL)[keyof typeof SKILL_LEVEL];

export const SKILL_LEVEL_OPTIONS = [
  { label: "Beginner",     value: SKILL_LEVEL.BEGINNER },
  { label: "Intermediate", value: SKILL_LEVEL.INTERMEDIATE },
  { label: "Advanced",     value: SKILL_LEVEL.ADVANCED },
] as const;

// ─────────────────────────────────────────────

const LEARNING_STYLE = {
  VIDEO:    "video",
  READING:  "reading",
  HANDS_ON: "hands_on",
  MIXED:    "mixed",
} as const;

export const LEARNING_STYLE_OPTIONS = [
  { label: "Video",    value: LEARNING_STYLE.VIDEO },
  { label: "Reading",  value: LEARNING_STYLE.READING },
  { label: "Hands-On", value: LEARNING_STYLE.HANDS_ON },
  { label: "Mixed",    value: LEARNING_STYLE.MIXED },
] as const;

// ─────────────────────────────────────────────

const LEARNING_GOAL = {
  GET_FIRST_JOB:    "get_first_job",
  SWITCH_COMPANY:   "switch_company",
  BECOME_SENIOR:    "become_senior",
  LEARN_TECHNOLOGY: "learn_technology",
  CRACK_INTERVIEWS: "crack_interviews",
  UPSKILL_TEAM:     "upskill_team",
} as const;
export type LearningGoal = (typeof LEARNING_GOAL)[keyof typeof LEARNING_GOAL];

export const LEARNING_GOAL_OPTIONS = [
  { label: "Get First Job",       value: LEARNING_GOAL.GET_FIRST_JOB },
  { label: "Switch Company",      value: LEARNING_GOAL.SWITCH_COMPANY },
  { label: "Become Senior",       value: LEARNING_GOAL.BECOME_SENIOR },
  { label: "Learn New Technology",value: LEARNING_GOAL.LEARN_TECHNOLOGY },
  { label: "Crack Interviews",    value: LEARNING_GOAL.CRACK_INTERVIEWS },
  { label: "Upskill My Team",     value: LEARNING_GOAL.UPSKILL_TEAM },
] as const;

// ─────────────────────────────────────────────

const LEARNING_DOMAIN = {
  BACKEND:          "backend",
  FRONTEND:         "frontend",
  DEVOPS:           "devops",
  CLOUD:            "cloud",
  AI_ML:            "ai_ml",
  DATA_ENGINEERING: "data_engineering",
  MOBILE:           "mobile",
  CYBERSECURITY:    "cybersecurity",
  SYSTEM_DESIGN:    "system_design",
} as const;

export const LEARNING_DOMAIN_OPTIONS = [
  { label: "Backend",          value: LEARNING_DOMAIN.BACKEND },
  { label: "Frontend",         value: LEARNING_DOMAIN.FRONTEND },
  { label: "DevOps",           value: LEARNING_DOMAIN.DEVOPS },
  { label: "Cloud",            value: LEARNING_DOMAIN.CLOUD },
  { label: "AI / ML",          value: LEARNING_DOMAIN.AI_ML },
  { label: "Data Engineering", value: LEARNING_DOMAIN.DATA_ENGINEERING },
  { label: "Mobile",           value: LEARNING_DOMAIN.MOBILE },
  { label: "Cybersecurity",    value: LEARNING_DOMAIN.CYBERSECURITY },
  { label: "System Design",    value: LEARNING_DOMAIN.SYSTEM_DESIGN },
] as const;

// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
// Course content module types (Phase 5)
// ─────────────────────────────────────────────

const MODULE_CONTENT_TYPE = {
  VIDEO:      "video",
  PDF:        "pdf",
  NOTES:      "notes",
  ASSESSMENT: "assessment",
} as const;

export const MODULE_CONTENT_TYPE_OPTIONS = [
  { label: "Video",      value: MODULE_CONTENT_TYPE.VIDEO },
  { label: "PDF",        value: MODULE_CONTENT_TYPE.PDF },
  { label: "Notes",      value: MODULE_CONTENT_TYPE.NOTES },
  { label: "Assessment", value: MODULE_CONTENT_TYPE.ASSESSMENT },
] as const;

// ─────────────────────────────────────────────

const COURSE_DIFFICULTY = {
  BEGINNER:     "beginner",
  INTERMEDIATE: "intermediate",
  ADVANCED:     "advanced",
} as const;

export const COURSE_DIFFICULTY_OPTIONS = [
  { label: "Beginner",     value: COURSE_DIFFICULTY.BEGINNER },
  { label: "Intermediate", value: COURSE_DIFFICULTY.INTERMEDIATE },
  { label: "Advanced",     value: COURSE_DIFFICULTY.ADVANCED },
] as const;

// ─────────────────────────────────────────────
// Practice / AI Interview Prep (Phase 8)
// ─────────────────────────────────────────────

export const PRACTICE_CATEGORY_OPTIONS = [
  { label: "Technical",  value: "technical" },
  { label: "Behavioral", value: "behavioral" },
] as const;

export const PRACTICE_DIFFICULTY_OPTIONS = [
  { label: "Beginner",     value: "beginner" },
  { label: "Intermediate", value: "intermediate" },
  { label: "Advanced",     value: "advanced" },
  { label: "Expert",       value: "expert" },
] as const;

export const PRACTICE_QUESTION_COUNT_OPTIONS = [
  { label: "1 question",   value: 1 },
  { label: "5 questions",  value: 5 },
  { label: "10 questions", value: 10 },
  { label: "15 questions", value: 15 },
  { label: "20 questions", value: 20 },
] as const;


// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
// Mentoring — tickets, reports, ratings
// ─────────────────────────────────────────────

export const MENTOR_REPORT_REASON = {
  UNRESPONSIVE:            "unresponsive",
  INAPPROPRIATE_BEHAVIOR:  "inappropriate_behavior",
  UNQUALIFIED:             "unqualified",
  OTHER:                   "other",
} as const;
export type MentorReportReason = (typeof MENTOR_REPORT_REASON)[keyof typeof MENTOR_REPORT_REASON];

export const MENTOR_REPORT_REASON_OPTIONS = [
  { label: "Unresponsive",           value: MENTOR_REPORT_REASON.UNRESPONSIVE },
  { label: "Inappropriate behavior", value: MENTOR_REPORT_REASON.INAPPROPRIATE_BEHAVIOR },
  { label: "Unqualified",            value: MENTOR_REPORT_REASON.UNQUALIFIED },
  { label: "Other",                  value: MENTOR_REPORT_REASON.OTHER },
] as const;

export const MENTOR_REPORT_STATUS = {
  OPEN:      "open",
  REVIEWING: "reviewing",
  RESOLVED:  "resolved",
  DISMISSED: "dismissed",
} as const;

export const MENTOR_CHANGE_REQUEST_STATUS = {
  PENDING:  "pending",
  APPROVED: "approved",
  DENIED:   "denied",
} as const;

export type MentorReportStatus = (typeof MENTOR_REPORT_STATUS)[keyof typeof MENTOR_REPORT_STATUS];

export type MentorChangeRequestStatus =
  (typeof MENTOR_CHANGE_REQUEST_STATUS)[keyof typeof MENTOR_CHANGE_REQUEST_STATUS];

// ─────────────────────────────────────────────

// Reported by the backend's warm-pool reconciler, never selected by a user:
// pool sizing is automatic, with `fixed`/`off` reachable only through the
// operator's LABS_WARM_POOL_OVERRIDES. No options list here for that reason.
export const WARM_POOL_MODE = {
  AUTO:  "auto",
  FIXED: "fixed",
  OFF:   "off",
} as const;

// ─────────────────────────────────────────────

export const ORG_TYPE = {
  SCHOOL:     "school",
  COLLEGE:    "college",
  UNIVERSITY: "university",
  BOOTCAMP:   "bootcamp",
  CORPORATE:  "corporate",
} as const;
export type OrgType = (typeof ORG_TYPE)[keyof typeof ORG_TYPE];

export const ORG_TYPE_OPTIONS = [
  { label: "School",             value: ORG_TYPE.SCHOOL },
  { label: "College",            value: ORG_TYPE.COLLEGE },
  { label: "University",         value: ORG_TYPE.UNIVERSITY },
  { label: "Bootcamp",           value: ORG_TYPE.BOOTCAMP },
  { label: "Company / Corporate", value: ORG_TYPE.CORPORATE },
] as const;

// ─────────────────────────────────────────────

export const SUGGESTED_SKILLS = [
  "Python", "JavaScript", "TypeScript", "Go", "Java", "Rust", "C++",
  "React", "Next.js", "Vue", "Angular", "Node.js",
  "PostgreSQL", "MySQL", "MongoDB", "Redis",
  "Docker", "Kubernetes", "Terraform", "Ansible",
  "AWS", "GCP", "Azure",
  "Git", "Linux", "Bash",
  "GraphQL", "REST", "gRPC",
  "TensorFlow", "PyTorch", "Pandas",
] as const;

// ─────────────────────────────────────────────

// Sheet tracker spaced-repetition growth schemes — how far the revision date
// jumps forward with each successful "Reviewed" click, given a per-sheet
// base interval in days.
const GROWTH_SCHEME = {
  DOUBLING: "doubling",
  LADDER:   "ladder",
  LINEAR:   "linear",
} as const;
export type GrowthScheme = (typeof GROWTH_SCHEME)[keyof typeof GROWTH_SCHEME];

export const GROWTH_SCHEME_OPTIONS = [
  { label: "Doubling",     value: GROWTH_SCHEME.DOUBLING, description: "Base, then double each time (7d → 14d → 28d → 56d...)" },
  { label: "Fixed ladder", value: GROWTH_SCHEME.LADDER,   description: "1d → 3d → 7d → 14d → 30d → 90d, then holds" },
  { label: "Linear",       value: GROWTH_SCHEME.LINEAR,   description: "Grows by the base interval each time (7d → 14d → 21d...)" },
] as const;

// Mirrors backend/internal/sheets/repo.go's nextRevisionDays — keep both in
// sync if the growth schemes ever change shape.
const REVISION_LADDER = [1, 3, 7, 14, 30, 90] as const;

/** How many days until the revision after `reviewCount` successful reviews (0 = the first scheduling). */
function revisionIntervalDays(scheme: GrowthScheme, base: number, reviewCount: number): number {
  switch (scheme) {
    case "ladder":
      return REVISION_LADDER[Math.min(reviewCount, REVISION_LADDER.length - 1)];
    case "linear":
      return base * (reviewCount + 1);
    default:
      return base * 2 ** reviewCount;
  }
}

/** The next `steps` interval lengths, for previewing a schedule as it's configured. */
export function revisionSchedulePreview(scheme: GrowthScheme, base: number, steps = 5): number[] {
  return Array.from({ length: steps }, (_, i) => revisionIntervalDays(scheme, base, i));
}

// ─────────────────────────────────────────────
// Mirrors backend/internal/mistakes/models.go's category constants and the
// mistake_entries_category_check DB constraint — keep all three in sync.

const MISTAKE_CATEGORY = {
  TENSE:                   "tense",
  ARTICLE:                 "article",
  PREPOSITION:             "preposition",
  SUBJECT_VERB_AGREEMENT:  "subject_verb_agreement",
  SPELLING:                "spelling",
  SENTENCE_FRAGMENT:       "sentence_fragment",
  RUN_ON:                  "run_on",
  VOCABULARY:              "vocabulary",
  PUNCTUATION:             "punctuation",
  OTHER:                   "other",
} as const;

export const MISTAKE_CATEGORY_OPTIONS = [
  { label: "Tense",                    value: MISTAKE_CATEGORY.TENSE },
  { label: "Article",                  value: MISTAKE_CATEGORY.ARTICLE },
  { label: "Preposition",              value: MISTAKE_CATEGORY.PREPOSITION },
  { label: "Subject-verb agreement",   value: MISTAKE_CATEGORY.SUBJECT_VERB_AGREEMENT },
  { label: "Spelling",                 value: MISTAKE_CATEGORY.SPELLING },
  { label: "Sentence fragment",        value: MISTAKE_CATEGORY.SENTENCE_FRAGMENT },
  { label: "Run-on sentence",          value: MISTAKE_CATEGORY.RUN_ON },
  { label: "Vocabulary",               value: MISTAKE_CATEGORY.VOCABULARY },
  { label: "Punctuation",              value: MISTAKE_CATEGORY.PUNCTUATION },
  { label: "Other",                    value: MISTAKE_CATEGORY.OTHER },
] as const;

// ─────────────────────────────────────────────
// GitLab project assignments & teams (Batch 2 — mirrors backend/internal/
// gitlab/models.go's constants; keep both in sync).
// ─────────────────────────────────────────────

const PROJECT_VISIBILITY = {
  PRIVATE:  "private",
  INTERNAL: "internal",
} as const;

export const PROJECT_VISIBILITY_OPTIONS = [
  { label: "Private",  value: PROJECT_VISIBILITY.PRIVATE },
  { label: "Internal", value: PROJECT_VISIBILITY.INTERNAL },
] as const;

const PROJECT_TEAM_MEMBER_ROLE = {
  LEAD:   "lead",
  MEMBER: "member",
} as const;

export const PROJECT_TEAM_MEMBER_ROLE_OPTIONS = [
  { label: "Lead",   value: PROJECT_TEAM_MEMBER_ROLE.LEAD },
  { label: "Member", value: PROJECT_TEAM_MEMBER_ROLE.MEMBER },
] as const;

// GitLab's own numeric access-level scale (project_team_members.gitlab_access_level).
const GITLAB_ACCESS_LEVEL = {
  REPORTER:   20,
  DEVELOPER:  30,
  MAINTAINER: 40,
} as const;

export const GITLAB_ACCESS_LEVEL_OPTIONS = [
  { label: "Reporter",   value: String(GITLAB_ACCESS_LEVEL.REPORTER) },
  { label: "Developer",  value: String(GITLAB_ACCESS_LEVEL.DEVELOPER) },
  { label: "Maintainer", value: String(GITLAB_ACCESS_LEVEL.MAINTAINER) },
] as const;

/** ProjectTeam.provision_status value that allows a re-provision. */
export const PROVISION_FAILED = "failed";

export const PROVISION_STATUS_LABEL: Record<string, string> = {
  pending:      "Pending",
  provisioning: "Provisioning",
  ready:        "Ready",
  failed:       "Failed",
};

// Badge variant per ProjectTeam.provision_status — shared by every surface
// that renders a team's provisioning state (cohort workspace list)
// so the color mapping only needs to be right in one place.
export const PROVISION_VARIANT: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  pending:      "outline",
  provisioning: "secondary",
  ready:        "default",
  failed:       "destructive",
};

// project_checkpoints.kind label + select-field options (Batch 7 / Phase B) —
// mirrors backend/internal/gitlab/models.go's CheckpointKind* constants.
export const CHECKPOINT_KIND_LABEL: Record<string, string> = {
  requirement_doc:      "Requirement doc",
  design_review:        "Design review",
  architecture_review:  "Architecture review",
  mr_review:            "MR review",
  milestone:            "Milestone",
};

export const CHECKPOINT_KIND_OPTIONS = [
  { label: "Milestone",            value: "milestone" },
  { label: "Requirement doc",      value: "requirement_doc" },
  { label: "Design review",        value: "design_review" },
  { label: "Architecture review",  value: "architecture_review" },
  { label: "MR review",            value: "mr_review" },
] as const;

// project_tasks.status label + badge-variant maps (Batch 7 / Phase B).
export const TASK_STATUS_LABEL: Record<string, string> = {
  todo:        "To do",
  in_progress: "In progress",
  review:      "In review",
  done:        "Done",
};

export const TASK_STATUS_VARIANT: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  todo:        "outline",
  in_progress: "secondary",
  review:      "secondary",
  done:        "default",
};

export const TASK_STATUS_OPTIONS = [
  { label: "To do",       value: "todo" },
  { label: "In progress", value: "in_progress" },
  { label: "In review",   value: "review" },
  { label: "Done",        value: "done" },
] as const;

// project_team_checkpoints.status / ci_status label + badge-variant maps —
// mirrors backend/internal/gitlab/models.go's Batch 5 constants. Shared by
// checkpoint-submissions.tsx (staff) and any student-facing surface so the
// color/label mapping stays in one place.
export const CHECKPOINT_STATUS_LABEL: Record<string, string> = {
  open:      "Open",
  submitted: "Submitted",
  approved:  "Approved",
  merged:    "Merged",
  graded:    "Graded",
};

export const CHECKPOINT_STATUS_VARIANT: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  open:      "outline",
  submitted: "secondary",
  approved:  "secondary",
  merged:    "default",
  graded:    "default",
};

export const CI_STATUS_LABEL: Record<string, string> = {
  none:     "No CI run yet",
  pending:  "Pending",
  running:  "Running",
  success:  "Passing",
  failed:   "Failed",
  canceled: "Canceled",
};

export const CI_STATUS_VARIANT: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  none:     "outline",
  pending:  "outline",
  running:  "secondary",
  success:  "default",
  failed:   "destructive",
  canceled: "outline",
};

// Batch 6: originality report status + capstone handoff label/variant maps —
// mirrors backend/internal/gitlab/models.go's OriginalityStatus*/HandoffStatus*
// constants. Both lifecycles share the same four states, but stay separate
// maps since they describe unrelated jobs (a table shared by coincidence
// would drift the moment one gains a state the other doesn't).
export const ORIGINALITY_STATUS_LABEL: Record<string, string> = {
  pending:  "Pending",
  running:  "Running",
  complete: "Complete",
  failed:   "Failed",
};

export const ORIGINALITY_STATUS_VARIANT: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  pending:  "outline",
  running:  "secondary",
  complete: "default",
  failed:   "destructive",
};

// Fork pre-selected for multi-member teams, transfer for solo teams (per
// kind-herding-cookie.md §0.5) — TeamHandoffDialog picks the default, this is
// just the option list/labels.
export const HANDOFF_MODE_OPTIONS = [
  { label: "Fork — new project, team keeps its current repo", value: "fork" },
  { label: "Transfer — moves the team's project itself",      value: "transfer" },
] as const;

export const HANDOFF_STATUS_LABEL: Record<string, string> = {
  pending:  "Pending",
  running:  "Running",
  complete: "Complete",
  failed:   "Failed",
};

export const HANDOFF_STATUS_VARIANT: Record<string, "default" | "secondary" | "destructive" | "outline"> = {
  pending:  "outline",
  running:  "secondary",
  complete: "default",
  failed:   "destructive",
};

export const MISTAKE_STATUS_LABEL: Record<string, string> = {
  new:       "New",
  recurring: "Recurring",
  improving: "Improving",
  resolved:  "Resolved",
};

export const MISTAKE_TREND_LABEL: Record<string, string> = {
  worsening: "Worsening",
  stable:    "Stable",
  improving: "Improving",
};

// ─────────────────────────────────────────────
// Mentor session booking — weekday labels (0 = Sunday … 6 = Saturday,
// matching Go's time.Weekday and AvailabilityRule.weekday) + the slot-length
// choices offered on both the weekly editor and one-off overrides.
// ─────────────────────────────────────────────

export const WEEKDAY_OPTIONS = [
  { label: "Sunday",    value: 0 },
  { label: "Monday",    value: 1 },
  { label: "Tuesday",   value: 2 },
  { label: "Wednesday", value: 3 },
  { label: "Thursday",  value: 4 },
  { label: "Friday",    value: 5 },
  { label: "Saturday",  value: 6 },
] as const;

export const SESSION_SLOT_LENGTH_OPTIONS = [
  { label: "15 minutes", value: "15" },
  { label: "30 minutes", value: "30" },
  { label: "45 minutes", value: "45" },
  { label: "60 minutes", value: "60" },
] as const;

// ─────────────────────────────────────────────
// Focus Wall — sticky-note color + category (mirrors backend/internal/
// focuswall/models.go's Color/Category constants and the focus_wall_notes
// CHECK constraints; keep all three in sync).
// ─────────────────────────────────────────────

const NOTE_COLOR = {
  YELLOW: "yellow",
  BLUE:   "blue",
  PINK:   "pink",
  GREEN:  "green",
} as const;

export const NOTE_COLOR_OPTIONS = [
  NOTE_COLOR.YELLOW,
  NOTE_COLOR.BLUE,
  NOTE_COLOR.PINK,
  NOTE_COLOR.GREEN,
] as const;

export const NOTE_CATEGORY = {
  ALL:      "all",
  PERSONAL: "personal",
  STUDY:    "study",
  URGENT:   "urgent",
} as const;

export const NOTE_CATEGORY_FILTER_OPTIONS = [
  { label: "All",      value: NOTE_CATEGORY.ALL },
  { label: "Personal", value: NOTE_CATEGORY.PERSONAL },
  { label: "Study",    value: NOTE_CATEGORY.STUDY },
  { label: "Urgent",   value: NOTE_CATEGORY.URGENT },
] as const;

// Habit tracker's per-habit color. Fixed 8-hue categorical set (not free-form
// hex) so every combination stays CVD-safe — see the `--habit-*` tokens and
// `bg-habit-*`/`fill-habit-*` utilities in globals.css. Order matches the
// backend's ColorPalette (habit/models.go), which is also the default
// rotation a new habit is assigned.
const HABIT_COLOR = {
  BLUE:    "blue",
  ORANGE:  "orange",
  AQUA:    "aqua",
  YELLOW:  "yellow",
  MAGENTA: "magenta",
  GREEN:   "green",
  VIOLET:  "violet",
  RED:     "red",
} as const;
export type HabitColorValue = (typeof HABIT_COLOR)[keyof typeof HABIT_COLOR];

export const HABIT_COLOR_OPTIONS = [
  { label: "Blue",    value: HABIT_COLOR.BLUE },
  { label: "Orange",  value: HABIT_COLOR.ORANGE },
  { label: "Aqua",    value: HABIT_COLOR.AQUA },
  { label: "Yellow",  value: HABIT_COLOR.YELLOW },
  { label: "Magenta", value: HABIT_COLOR.MAGENTA },
  { label: "Green",   value: HABIT_COLOR.GREEN },
  { label: "Violet",  value: HABIT_COLOR.VIOLET },
  { label: "Red",     value: HABIT_COLOR.RED },
] as const;

// ─────────────────────────────────────────────
// Tickets — shared support + mentorship ticket lifecycle
// (backend/internal/tickets; kind=support|mentorship)
// ─────────────────────────────────────────────

export const TICKET_KIND = {
  SUPPORT: "support",
  MENTORSHIP: "mentorship",
} as const;
export type TicketKind = (typeof TICKET_KIND)[keyof typeof TICKET_KIND];

// Union of both kinds' status vocabularies — in_progress/resolved are
// support-only, assigned is mentorship-only (mirrors tickets.IsValidStatus).
const TICKET_STATUS = {
  OPEN:        "open",
  IN_PROGRESS: "in_progress",
  ASSIGNED:    "assigned",
  RESOLVED:    "resolved",
  CLOSED:      "closed",
} as const;
export type TicketStatus = (typeof TICKET_STATUS)[keyof typeof TICKET_STATUS];

export const SUPPORT_STATUS_OPTIONS = [
  { label: "Open",        value: TICKET_STATUS.OPEN },
  { label: "In progress", value: TICKET_STATUS.IN_PROGRESS },
  { label: "Resolved",    value: TICKET_STATUS.RESOLVED },
  { label: "Closed",      value: TICKET_STATUS.CLOSED },
] as const;


// Category/priority — support tickets only.
const TICKET_CATEGORY = {
  TECHNICAL:      "technical",
  BILLING:        "billing",
  ACCOUNT:        "account",
  COURSE_CONTENT: "course_content",
  OTHER:          "other",
} as const;
export type TicketCategory = (typeof TICKET_CATEGORY)[keyof typeof TICKET_CATEGORY];

export const TICKET_CATEGORY_OPTIONS = [
  { label: "Technical issue", value: TICKET_CATEGORY.TECHNICAL },
  { label: "Billing",         value: TICKET_CATEGORY.BILLING },
  { label: "Account",         value: TICKET_CATEGORY.ACCOUNT },
  { label: "Course content",  value: TICKET_CATEGORY.COURSE_CONTENT },
  { label: "Other",           value: TICKET_CATEGORY.OTHER },
] as const;

const TICKET_PRIORITY = {
  LOW:    "low",
  NORMAL: "normal",
  HIGH:   "high",
} as const;
export type TicketPriority = (typeof TICKET_PRIORITY)[keyof typeof TICKET_PRIORITY];

export const TICKET_PRIORITY_OPTIONS = [
  { label: "Low",    value: TICKET_PRIORITY.LOW },
  { label: "Normal", value: TICKET_PRIORITY.NORMAL },
  { label: "High",   value: TICKET_PRIORITY.HIGH },
] as const;

// Org domain verification: the TXT record an org publishes at
// `${DNS_VERIFICATION_LABEL}.<domain>`. Mirrors backend orgs.DNSVerificationLabel.
export const DNS_VERIFICATION_LABEL = "_mindforge-verification";
export const DNS_VERIFICATION_VALUE_PREFIX = "mindforge-verification=";

// Domain used for sample addresses and URLs in form placeholders and hints.
export const PLACEHOLDER_DOMAIN = "mindforge.test";

// Instructor & org analytics. Defaults mirror the backend query defaults.
export const ANALYTICS_DEFAULT_DAYS = 30;
export const ANALYTICS_TREND_DAY_OPTIONS = [
  { label: "Last 7 days",   value: 7 },
  { label: "Last 30 days",  value: 30 },
  { label: "Last 90 days",  value: 90 },
  { label: "Last 180 days", value: 180 },
] as const;

export const AT_RISK_DEFAULT_INACTIVE_DAYS = 14;
export const AT_RISK_INACTIVE_DAY_OPTIONS = [
  { label: "Inactive 7+ days",  value: 7 },
  { label: "Inactive 14+ days", value: 14 },
  { label: "Inactive 30+ days", value: 30 },
  { label: "Inactive 60+ days", value: 60 },
] as const;

export const AT_RISK_DEFAULT_PROGRESS_PCT = 25;
export const AT_RISK_PROGRESS_OPTIONS = [
  { label: "Under 10% done", value: 10 },
  { label: "Under 25% done", value: 25 },
  { label: "Under 50% done", value: 50 },
] as const;

export const RISK_REASON_LABEL: Record<string, string> = {
  inactive:     "Inactive",
  low_progress: "Low progress",
};

export const ANALYTICS_PAGE_STEP = 10;
export const ANALYTICS_QUESTIONS_DEFAULT_LIMIT = 10;
export const ANALYTICS_STUDENTS_DEFAULT_LIMIT = 25;
export const ANALYTICS_MAX_LIMIT = 200;
export const ORG_COURSES_DEFAULT_LIMIT = 20;

// Notification preference labels (Settings > Profile > Preferences).
export const NOTIFICATION_LABELS = {
  weeklyRecap: "Weekly recap email",
} as const;
