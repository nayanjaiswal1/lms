export const PERMISSIONS = {
  COURSES: {
    VIEW:           "courses.view",
    ENROLL:         "courses.enroll",
    CREATE:         "courses.create",
    EDIT:           "courses.edit",
    PUBLISH:        "courses.publish",
    DELETE:         "courses.delete",
    VIEW_ANALYTICS: "courses.view_analytics",
  },
  ASSESSMENTS: {
    TAKE:             "assessments.take",
    VIEW_ASSIGNED:    "assessments.view_assigned",
    CREATE:           "assessments.create",
    EDIT:             "assessments.edit",
    PUBLISH:          "assessments.publish",
    DELETE:           "assessments.delete",
    VIEW_RESULTS:     "assessments.view_results",
    MANAGE_QUESTIONS: "assessments.manage_questions",
    MANAGE_BATCHES:   "assessments.manage_batches",
  },
  PRACTICE: {
    USE: "practice.use",
  },
  MENTORING: {
    CHAT:            "mentoring.chat",
    MANAGE_BATCHES:  "mentoring.manage_batches",
    VIEW_STUDENTS:   "mentoring.view_students",
  },
  CONTENT: {
    WIKI:            "content.wiki",
    SYSTEM_DESIGN:   "content.system_design",
    INTERVIEW_BOARD: "content.interview_board",
    LOAD_TEST:       "content.load_test",
    SHEETS:          "content.sheets",
    SRS:             "content.srs",
    CERTIFICATES:    "content.certificates",
  },
  ADMIN: {
    VIEW_MEMBERS:       "admin.view_members",
    MANAGE_MEMBERS:     "admin.manage_members",
    MANAGE_ROLES:       "admin.manage_roles",
    MANAGE_PERMISSIONS: "admin.manage_permissions",
    VIEW_AUDIT_LOG:     "admin.view_audit_log",
    MANAGE_ORG:         "admin.manage_org",
    VIEW_JOBS:          "admin.view_jobs",
    MANAGE_JOBS:        "admin.manage_jobs",
  },
} as const

export type PermissionCode = string
