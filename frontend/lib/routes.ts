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
  REVIEW:              "/review",
  CERTIFICATES:        "/certificates",
  SHEETS:              "/sheets",
  SHEETS_COMPARE:      "/sheets/compare",

  // Mentor
  MENTOR:              "/mentor",
  MENTOR_MESSAGES:     "/mentor/messages",
  MENTOR_BATCHES:      "/mentor/batches",

  // Instructor
  INSTRUCTOR_DASHBOARD:  "/instructor/dashboard",
  INSTRUCTOR_COURSES:    "/instructor/courses",
  INSTRUCTOR_NEW_COURSE: "/instructor/courses/new",

  // Assessments — student
  ASSESSMENTS:         "/assessments",

  // Assessments — staff (author / manage)
  ADMIN_ASSESSMENTS:     "/instructor/assessments",
  ADMIN_ASSESSMENT_NEW:  "/instructor/assessments/new",
  ADMIN_QUESTION_BANK:   "/instructor/question-bank",
  ADMIN_BATCHES:         "/instructor/batches",

  // Practice / AI interview prep
  PRACTICE:            "/practice",
  PRACTICE_NEW:        "/practice/new",

  // Interview practice readiness (mock assessment system)
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
  ADMIN_RBAC_PERMISSIONS:  "/admin/rbac/permissions",
  ADMIN_RBAC_AUDIT:        "/admin/rbac/audit",

  // Admin — Jobs
  ADMIN_JOBS:              "/admin/jobs",
  ADMIN_JOBS_WORKERS:      "/admin/jobs/workers",
  adminOrgQuotas:          (orgID: string) => `/admin/orgs/${orgID}/quotas`,

  // Org management
  ORG_CREATE:           "/org/create",
  ORG_SETUP:            "/org/setup",
  ORG_SETTINGS:         "/org/settings",
  ORG_SETTINGS_MEMBERS: "/org/settings/members",
  ORG_SETTINGS_DOMAINS: "/org/settings/domains",
  ORG_SETTINGS_AUTH:    "/org/settings/authentication",
  ORG_SETTINGS_AUDIT:   "/org/settings/audit-log",
  ORG_SETTINGS_JOBS:    "/org/settings/jobs",

  // Dynamic builders — use instead of template literals at call sites
  course:              (slug: string)                      => `/courses/${slug}`,
  courseLearn:         (slug: string)                      => `/courses/${slug}/learn`,
  courseLearnModule:   (slug: string, moduleId: string)    => `/courses/${slug}/learn/${moduleId}`,
  module:              (slug: string, moduleId: string)    => `/courses/${slug}/${moduleId}`,
  instructorBatch:     (id: string)                        => `/instructor/batches/${id}`,
  instructorCourse:    (id: string)                        => `/instructor/courses/${id}`,
  instructorCourseAnalytics: (id: string)                  => `/instructor/courses/${id}/analytics`,
  mentorBatch:         (id: string)                        => `/mentor/batches/${id}`,
  mentorBatchChat:     (id: string)                        => `/mentor/batches/${id}/chat`,
  practiceSession:     (id: string)                        => `/practice/${id}`,
  certificate:         (uuid: string)                      => `/certificates/${uuid}`,
  sheet:               (slug: string)                      => `/sheets/${slug}`,
  assessment:          (id: string)                        => `/assessments/${id}`,
  assessmentTake:      (id: string)                        => `/assessments/${id}/take`,
  assessmentResult:    (attemptId: string)                 => `/assessments/result/${attemptId}`,
  adminAssessment:     (id: string)                        => `/instructor/assessments/${id}`,
  adminAssessmentResults: (id: string)                     => `/instructor/assessments/${id}/results`,
  adminAssessmentReview: (id: string)                      => `/instructor/assessments/${id}/review`,
  interview:           (id: string)                        => `/interview/${id}`,
  interviewLive:       (id: string)                        => `/interview/${id}/live`,
  interviewJoin:       (code: string)                      => `/interview/join/${code}`,
  design:              (id: string)                        => `/design/${id}`,
  wikiSpace:           (spaceSlug: string)                 => `/wiki/${spaceSlug}`,
  wikiPage:            (spaceSlug: string, ...path: string[]) => `/wiki/${spaceSlug}/${path.join("/")}`,
  wikiEdit:            (spaceSlug: string, ...path: string[]) => `/wiki/${spaceSlug}/${path.join("/")}/edit`,
  instructorEditCourse:(id: string)                        => `/instructor/courses/${id}/edit`,
  publicProfile:       (slug: string)                      => `/u/${slug}`,
} as const;

export default ROUTES;
