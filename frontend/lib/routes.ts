const ROUTES = {
  // Public
  HOME:                "/",
  ORG_LANDING:         "/org",
  COURSES:             "/courses",
  DEMO:                "/demo",
  DEMO_TOUR:           "/demo/tour",
  LEGAL_TERMS:         "/legal/terms",
  LEGAL_PRIVACY:       "/legal/privacy",
  LEGAL_REFUND_POLICY: "/legal/refund-policy",

  // Auth
  LOGIN:               "/login",
  REGISTER:            "/register",
  FORGOT_PASSWORD:     "/forgot-password",
  RESET_PASSWORD:      "/reset-password",
  VERIFY_EMAIL:        "/verify-email",
  ORG_SELECT:          "/org-select",
  AUTH_CALLBACK:       "/auth/callback",

  // Onboarding
  ONBOARDING:          "/onboarding",

  // Student
  DASHBOARD:           "/dashboard",
  LEARN:               "/learn",
  TEACH:               "/teach",
  NOW:                 "/now",
  PLAN:                "/plan",
  BOARD:               "/board",
  HABITS:              "/habits",
  CALENDAR:            "/calendar",
  LEADERBOARD:         "/leaderboard",
  REVIEW:              "/review",
  MISTAKES:            "/mistakes",
  SHEETS:              "/sheets",
  SHEETS_NEW:          "/sheets/new",
  SHEETS_COMPARE:      "/sheets/compare",
  JOURNAL:             "/journal",
  JOURNAL_NEW:         "/journal/new",
  DIARY:               "/diary",
  diaryEntry:          (date: string) => `/diary/${date}`,

  // Mentoring
  MENTORING:               "/mentoring",
  MENTORING_TICKETS:       "/mentoring/tickets",
  MENTORING_CONVERSATIONS: "/mentoring/conversations",

  // Mentor directory
  MENTORS:             "/mentors",

  // Mentor session booking
  SESSIONS:                 "/sessions",
  SESSION_CREDITS:          "/sessions/credits",
  SESSION_AVAILABILITY:     "/mentoring/availability",
  SESSION_BOOKING_SETTINGS: "/settings/session-booking",

  // Courses — "/courses" already serves both students and staff, branching
  // by permission (see app/(app)/courses/page.tsx)
  COURSE_NEW:              "/courses/new",

  // Assessments — "/assessments" now serves both students and staff,
  // branching by permission (see app/(app)/assessments/page.tsx)
  ASSESSMENT_NEW:          "/assessments/new",

  // Question bank
  QUESTION_BANK:           "/question-bank",

  // Batches (assessment delivery)
  BATCHES:                 "/batches",
  COHORT_GROUPS:           "/cohort-groups",

  // GitLab project assignments & teams (instructor/admin management)
  PROJECTS:                "/projects",
  PROJECTS_NEW:            "/projects/new",

  // Project marketplace (Phase A, Slice 1): staff-managed requirement postings
  // and the open board any org member browses/applies to.
  PROJECTS_REQUIREMENTS:     "/projects/requirements",
  PROJECTS_REQUIREMENTS_NEW: "/projects/requirements/new",
  PROJECTS_BOARD:            "/projects/board",

  // Assessments — student
  ASSESSMENTS:         "/assessments",

  // Interview Prep — single entry point for both quick topic drills and a
  // full job-title/JD-derived scored mock test (see plan_type on PrepPlan)
  INTERVIEW_PREP:      "/interview-prep",
  INTERVIEW_PREP_NEW:  "/interview-prep/new",

  // Roadmap — AI personalized learning paths
  ROADMAP:             "/roadmap",
  ROADMAP_NEW:         "/roadmap/new",
  ROADMAP_DISCOVER:    "/roadmap/discover",

  // Interview practice readiness
  INTERVIEW_PROGRESS:  "/interview/progress",
  INTERVIEW_SKILLS:    "/interview/skills",

  // Tools (feature-gated)
  WIKI:                "/wiki",

  // Algorithm Visualizer — personal tool, ungated
  ALGO_VISUALIZER:     "/algo-visualizer",

  // Interview Experiences — crowd-sourced company/position Q&A board.
  INTERVIEW_EXP:       "/interview-exp",
  INTERVIEW_EXP_NEW:   "/interview-exp/new",
  INTERVIEW_EXP_FAQ:   "/interview-exp/faq",

  // Platform
  BILLING:             "/billing",

  // Highlights (AI-assisted text selection + saved revision)
  HIGHLIGHTS:          "/highlights",

  // Support — general-purpose helpdesk tickets. Staff queue is a ?view=queue
  // tab on the same page (frontend/app/(app)/support/page.tsx), not a
  // separate route — it and "my tickets" share one page shell.
  SUPPORT:             "/support",

  // Focus Wall — personal sticky-note corkboard
  FOCUS_WALL:          "/focus-wall",

  // Settings
  SETTINGS_PROFILE:               "/settings/profile",
  SETTINGS_SECURITY:              "/settings/security",
  SETTINGS_PRIVACY:               "/settings/privacy",
  SETTINGS_INTEGRATIONS:          "/settings/integrations",
  SETTINGS_INTEGRATIONS_ACTIVITY: "/settings/integrations/activity",

  // Legal — consent holding page shown when a policy version changes
  LEGAL_ACCEPT:        "/legal/accept",

  // Admin — RBAC
  ADMIN_RBAC_ROLES:        "/admin/rbac/roles",
  ADMIN_RBAC_PERMISSIONS:  "/admin/rbac/permissions",
  ADMIN_RBAC_AUDIT:        "/admin/rbac/audit",
  USERS:                   "/users",
  userDetail:              (id: string)                        => `/users/${id}`,

  // Admin — Labs
  ADMIN_LABS_WARM_POOLS:   "/admin/labs/warm-pools",
  ADMIN_LABS_USAGE:        "/admin/labs/usage",

  // Admin — Payments
  ADMIN_COUPONS:           "/admin/coupons",

  // Admin — Moderation
  ADMIN_CONTENT_REPORTS:   "/admin/content-reports",

  // Platform Admin (super_admin console — cross-tenant)
  PLATFORM_JOBS:           "/platform/jobs",
  PLATFORM_JOBS_WORKERS:   "/platform/jobs/workers",
  PLATFORM_HIGHLIGHTS:            "/platform/highlights",
  PLATFORM_HIGHLIGHTS_BY_SOURCE:  "/platform/highlights/by-source",
  PLATFORM_HIGHLIGHTS_BY_MODEL:   "/platform/highlights/by-model",
  PLATFORM_FEATURES:       "/platform/features",
  PLATFORM_PRICING:        "/platform/pricing",
  platformJob:             (id: string) => `/platform/jobs/${id}`,
  platformOrgQuotas:       (orgID: string) => `/platform/orgs/${orgID}/quotas`,
  platformOrgFeatures:     (orgID: string) => `/platform/features/${orgID}`,

  // Org management
  ORG_CREATE:              "/org/create",
  ORG_SETUP:               "/org/setup",
  ORG_SETTINGS:            "/org/settings",
  ORG_SETTINGS_DOMAINS:    "/org/settings/domains",
  ORG_SETTINGS_AUTH:       "/org/settings/authentication",
  ORG_SETTINGS_AUDIT:      "/org/settings/audit-log",
  ORG_SETTINGS_JOBS:       "/org/settings/jobs",
  ORG_SETTINGS_INVITES:    "/org/settings/invites",
  ORG_SETTINGS_INTEGRATIONS: "/org/settings/integrations",
  orgSettingsJobs:      (orgId: string) => `/org/settings/jobs/${orgId}`,
  orgSettingsJob:       (orgId: string, jobId: string) => `/org/settings/jobs/${orgId}/${jobId}`,

  // Dynamic builders
  course:                   (slug: string)                      => `/courses/${slug}`,
  courseLearn:              (slug: string)                      => `/courses/${slug}/learn`,
  courseLearnModule:        (slug: string, moduleId: string)    => `/courses/${slug}/learn/${moduleId}`,
  courseSolve:              (slug: string, problem: string)     => `/courses/${slug}/solve/${problem}`,
  courseReceipt:            (slug: string, purchaseId: string)  => `/courses/${slug}/checkout/receipt/${purchaseId}`,
  module:                   (slug: string, moduleId: string)    => `/courses/${slug}/${moduleId}`,
  courseEdit:               (slug: string)                      => `/courses/${slug}/edit`,
  courseEditSettings:       (slug: string)                      => `/courses/${slug}/edit/settings`,
  courseEditAnalytics:      (slug: string)                      => `/courses/${slug}/edit/analytics`,
  batch:                    (id: string)                        => `/batches/${id}`,
  batchImport:              (id: string)                        => `/batches/${id}/import`,
  batchTests:               (id: string)                        => `/batches/${id}/tests`,
  cohortGroup:              (id: string)                        => `/cohort-groups/${id}`,
  projectAssignment:        (id: string)                        => `/projects/${id}`,
  myProject:                (teamId: string)                    => `/projects/team/${teamId}`,
  teamShowcase:             (teamId: string)                    => `/projects/team/${teamId}/showcase`,
  projectRequirement:       (id: string)                        => `/projects/requirements/${id}`,
  boardRequirement:         (id: string)                        => `/projects/board/${id}`,
  assessmentEdit:           (id: string)                        => `/assessments/${id}/edit`,
  assessmentEditBatches:    (id: string)                        => `/assessments/${id}/edit/batches`,
  assessmentEditSettings:   (id: string)                        => `/assessments/${id}/edit/settings`,
  assessmentResults:        (id: string)                        => `/assessments/${id}/results`,
  assessmentReview:         (id: string)                        => `/assessments/${id}/review`,
  mentoringTicketDetail:    (id: string)                        => `/mentoring/tickets/${id}`,
  mentoringTicketChat:      (id: string)                        => `/mentoring/tickets/${id}/chat`,
  mentor:                   (id: string)                        => `/mentors/${id}`,
  session:                  (id: string)                        => `/sessions/${id}`,
  menteeProgress:           (studentId: string)                 => `/mentoring/mentees/${studentId}`,
  mentorConversation:       (id: string)                        => `/mentoring/conversations/${id}/chat`,
  practiceSession:          (id: string)                        => `/practice/${id}`,
  interviewPrepPlan:        (id: string)                        => `/interview-prep/${id}`,
  interviewPrepCoding:      (id: string)                        => `/interview-prep/${id}/coding`,
  interviewPrepReport:      (id: string)                        => `/interview-prep/${id}/report`,
  roadmap:                  (id: string)                        => `/roadmap/${id}`,
  certificate:              (uuid: string)                      => `/certificates/${uuid}`,
  sheet:                    (slug: string)                      => `/sheets/${slug}`,
  sheetJoin:                (slug: string)                      => `/sheets/join/${slug}`,
  journalEdit:              (id: string)                        => `/journal/${id}/edit`,
  assessmentTake:           (id: string)                        => `/assessments/${id}/take`,
  assessmentResult:         (attemptId: string)                 => `/assessments/result/${attemptId}`,
  attemptProctoring:        (attemptId: string)                 => `/assessments/attempts/${attemptId}/proctoring`,
  courseFinalTest:          (slug: string)                     => `/courses/${slug}/final-test`,
  courseCheckoutReturn:     (slug: string)                     => `/courses/${slug}/checkout/return`,
  wikiSpace:                (spaceSlug: string)                 => `/wiki/${spaceSlug}`,
  wikiPage:                 (spaceSlug: string, ...path: string[]) => `/wiki/${spaceSlug}/${path.join("/")}`,
  interviewExpPost:         (id: string)                        => `/interview-exp/${id}`,
  wikiEdit:                 (spaceSlug: string, ...path: string[]) => `/wiki/${spaceSlug}/edit/${path.join("/")}`,
  publicProfile:            (slug: string)                      => `/u/${slug}`,

  // Labs
  LABS:                     "/labs",
  lab:                      (labId: string)                     => `/labs/${labId}`,
  labSession:               (sessionId: string)                 => `/labs/sessions/${sessionId}`,
  labSessionResult:         (sessionId: string)                 => `/labs/sessions/${sessionId}/result`,

  // Hiring / public assessment (no login required)
  hireLanding:              (code: string)                      => `/hire/${code}`,

  // Public roadmap Discover gallery (no login required)
  PUBLIC_ROADMAPS:          "/roadmaps",
  publicRoadmap:            (id: string)                        => `/roadmaps/${id}`,

  // Calendar invite acceptance (no login required)
  calendarInviteAccept:     (token: string)                     => `/calendar/invite/${token}`,
} as const;

const COURSE_LEARN_ROUTE = /^\/courses\/[^/]+\/learn\/[^/]+/;

/** True for the course module reader (`/courses/:slug/learn/:moduleId`) — the
 * one page that hides the product sidebar for a distraction-free read. */
export function isCourseLearnRoute(pathname: string): boolean {
  return COURSE_LEARN_ROUTE.test(pathname);
}

const PROCTORED_ASSESSMENT_ROUTE = /^\/assessments\/[^/]+\/take(\/|$)/;

/** True for the proctored assessment-taking flow (`/assessments/:id/take`) —
 * camera/mic capture and monitoring rules, so no floating global UI (e.g. the
 * active-lab resume bar) should render on top of it. */
export function isProctoredAssessmentRoute(pathname: string): boolean {
  return PROCTORED_ASSESSMENT_ROUTE.test(pathname);
}

export default ROUTES;
