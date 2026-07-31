const ROUTES = {
  // Public
  HOME:                "/",
  COURSES:             "/courses",
  DEMO:                "/demo",
  DEMO_TOUR:           "/demo/tour",

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
  CALENDAR:            "/calendar",
  LEADERBOARD:         "/leaderboard",
  REVIEW:              "/review",
  MISTAKES:            "/mistakes",
  SHEETS:              "/sheets",
  SHEETS_NEW:          "/sheets/new",
  SHEETS_COMPARE:      "/sheets/compare",

  // Mentoring
  MENTORING:           "/mentoring",
  MENTORING_TICKETS:   "/mentoring/tickets",

  // Mentor directory
  MENTORS:             "/mentors",

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

  // Interview Experiences — crowd-sourced company/position Q&A board.
  INTERVIEW_EXP:       "/interview-exp",
  INTERVIEW_EXP_NEW:   "/interview-exp/new",
  INTERVIEW_EXP_FAQ:   "/interview-exp/faq",

  // Platform
  BILLING:             "/billing",

  // Highlights (AI-assisted text selection + saved revision)
  HIGHLIGHTS:          "/highlights",

  // Settings
  SETTINGS_PROFILE:               "/settings/profile",
  SETTINGS_SECURITY:              "/settings/security",
  SETTINGS_INTEGRATIONS:          "/settings/integrations",
  SETTINGS_INTEGRATIONS_ACTIVITY: "/settings/integrations/activity",

  // Admin — RBAC
  ADMIN_RBAC_ROLES:        "/admin/rbac/roles",
  ADMIN_RBAC_PERMISSIONS:  "/admin/rbac/permissions",
  ADMIN_RBAC_AUDIT:        "/admin/rbac/audit",
  USERS:                   "/users",

  // Admin — Labs
  ADMIN_LABS_WARM_POOLS:   "/admin/labs/warm-pools",

  // Admin — Payments
  ADMIN_COUPONS:           "/admin/coupons",

  // Platform Admin (super_admin console — cross-tenant)
  PLATFORM_JOBS:           "/platform/jobs",
  PLATFORM_JOBS_WORKERS:   "/platform/jobs/workers",
  PLATFORM_HIGHLIGHTS:            "/platform/highlights",
  PLATFORM_HIGHLIGHTS_BY_SOURCE:  "/platform/highlights/by-source",
  PLATFORM_HIGHLIGHTS_BY_MODEL:   "/platform/highlights/by-model",
  platformJob:             (id: string) => `/platform/jobs/${id}`,
  platformOrgQuotas:       (orgID: string) => `/platform/orgs/${orgID}/quotas`,

  // Org management
  ORG_CREATE:              "/org/create",
  ORG_SETUP:               "/org/setup",
  ORG_SETTINGS:            "/org/settings",
  ORG_SETTINGS_MEMBERS:    "/org/settings/members",
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
  assessmentEdit:           (id: string)                        => `/assessments/${id}/edit`,
  assessmentEditBatches:    (id: string)                        => `/assessments/${id}/edit/batches`,
  assessmentEditSettings:   (id: string)                        => `/assessments/${id}/edit/settings`,
  assessmentResults:        (id: string)                        => `/assessments/${id}/results`,
  assessmentReview:         (id: string)                        => `/assessments/${id}/review`,
  mentoringTicketDetail:    (id: string)                        => `/mentoring/tickets/${id}`,
  mentoringTicketChat:      (id: string)                        => `/mentoring/tickets/${id}/chat`,
  mentor:                   (id: string)                        => `/mentors/${id}`,
  practiceSession:          (id: string)                        => `/practice/${id}`,
  interviewPrepPlan:        (id: string)                        => `/interview-prep/${id}`,
  interviewPrepCoding:      (id: string)                        => `/interview-prep/${id}/coding`,
  interviewPrepReport:      (id: string)                        => `/interview-prep/${id}/report`,
  roadmap:                  (id: string)                        => `/roadmap/${id}`,
  certificate:              (uuid: string)                      => `/certificates/${uuid}`,
  sheet:                    (slug: string)                      => `/sheets/${slug}`,
  sheetJoin:                (slug: string)                      => `/sheets/join/${slug}`,
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
