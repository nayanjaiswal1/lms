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
  LEADERBOARD:         "/leaderboard",
  REVIEW:              "/review",
  CERTIFICATES:        "/certificates",
  SHEETS:              "/sheets",
  SHEETS_COMPARE:      "/sheets/compare",

  // Mentoring
  MENTORING:           "/mentoring",
  MENTORING_MESSAGES:  "/mentoring/messages",
  MENTORING_BATCHES:   "/mentoring/batches",

  // Course management (author/instructor)
  MANAGE_COURSES:          "/courses/manage",
  MANAGE_COURSES_NEW:      "/courses/manage/new",

  // Assessment management (author/instructor)
  MANAGE_ASSESSMENTS:      "/assessments/manage",
  MANAGE_ASSESSMENT_NEW:   "/assessments/manage/new",

  // Question bank
  QUESTION_BANK:           "/question-bank",

  // Batches (assessment delivery)
  BATCHES:                 "/batches",

  // Assessments — student
  ASSESSMENTS:         "/assessments",

  // Practice / AI interview prep
  PRACTICE:            "/practice",
  PRACTICE_NEW:        "/practice/new",

  // Interview practice readiness
  INTERVIEW_PROGRESS:  "/interview/progress",
  INTERVIEW_SKILLS:    "/interview/skills",

  // Tools (feature-gated)
  WIKI:                "/wiki",
  DESIGN:              "/design",
  INTERVIEW:           "/interview",
  INTERVIEW_NEW:       "/interview/new",
  LOAD_TEST:           "/load-test",

  // Platform
  BILLING:             "/billing",

  // Settings
  SETTINGS_PROFILE:    "/settings/profile",

  // Admin — RBAC
  ADMIN_RBAC_ROLES:        "/admin/rbac/roles",
  ADMIN_RBAC_ROLES_NEW:    "/admin/rbac/roles/new",
  ADMIN_RBAC_PERMISSIONS:  "/admin/rbac/permissions",
  ADMIN_RBAC_AUDIT:        "/admin/rbac/audit",

  // Admin — Jobs
  ADMIN_JOBS:              "/admin/jobs",
  ADMIN_JOBS_WORKERS:      "/admin/jobs/workers",
  adminJob:                (id: string) => `/admin/jobs/${id}`,
  adminOrgQuotas:          (orgID: string) => `/admin/orgs/${orgID}/quotas`,

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
  orgSettingsJobs:      (orgId: string) => `/org/settings/jobs/${orgId}`,
  orgSettingsJob:       (orgId: string, jobId: string) => `/org/settings/jobs/${orgId}/${jobId}`,

  // Dynamic builders
  course:                   (slug: string)                      => `/courses/${slug}`,
  courseLearn:              (slug: string)                      => `/courses/${slug}/learn`,
  courseLearnModule:        (slug: string, moduleId: string)    => `/courses/${slug}/learn/${moduleId}`,
  module:                   (slug: string, moduleId: string)    => `/courses/${slug}/${moduleId}`,
  manageCourse:             (id: string)                        => `/courses/manage/${id}`,
  manageCourseEdit:         (id: string)                        => `/courses/manage/${id}/edit`,
  manageCourseAnalytics:    (id: string)                        => `/courses/manage/${id}/analytics`,
  batch:                    (id: string)                        => `/batches/${id}`,
  manageAssessment:         (id: string)                        => `/assessments/manage/${id}`,
  manageAssessmentResults:  (id: string)                        => `/assessments/manage/${id}/results`,
  manageAssessmentReview:   (id: string)                        => `/assessments/manage/${id}/review`,
  mentoringBatch:           (id: string)                        => `/mentoring/batches/${id}`,
  mentoringBatchChat:       (id: string)                        => `/mentoring/batches/${id}/chat`,
  practiceSession:          (id: string)                        => `/practice/${id}`,
  certificate:              (uuid: string)                      => `/certificates/${uuid}`,
  sheet:                    (slug: string)                      => `/sheets/${slug}`,
  assessment:               (id: string)                        => `/assessments/${id}`,
  assessmentTake:           (id: string)                        => `/assessments/${id}/take`,
  assessmentResult:         (attemptId: string)                 => `/assessments/result/${attemptId}`,
  attemptProctoring:        (attemptId: string)                 => `/assessments/manage/attempts/${attemptId}/proctoring`,
  interview:                (id: string)                        => `/interview/${id}`,
  interviewLive:            (id: string)                        => `/interview/${id}/live`,
  interviewJoin:            (code: string)                      => `/interview/join/${code}`,
  design:                   (id: string)                        => `/design/${id}`,
  wikiSpace:                (spaceSlug: string)                 => `/wiki/${spaceSlug}`,
  wikiPage:                 (spaceSlug: string, ...path: string[]) => `/wiki/${spaceSlug}/${path.join("/")}`,
  wikiEdit:                 (spaceSlug: string, ...path: string[]) => `/wiki/${spaceSlug}/${path.join("/")}/edit`,
  publicProfile:            (slug: string)                      => `/u/${slug}`,

  // Labs
  LABS:                     "/labs",
  lab:                      (labId: string)                     => `/labs/${labId}`,
  labSession:               (sessionId: string)                 => `/labs/sessions/${sessionId}`,
  labSessionResult:         (sessionId: string)                 => `/labs/sessions/${sessionId}/result`,

  // Hiring / public assessment (no login required)
  hireLanding:              (code: string)                      => `/hire/${code}`,
} as const;

export default ROUTES;
