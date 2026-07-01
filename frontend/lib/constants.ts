// ─────────────────────────────────────────────
// App-wide constants & option lists.
// Never define these inside a component.
// Import the *_OPTIONS arrays as `options` props.
// ─────────────────────────────────────────────

export const DIFFICULTY = {
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

export const PROBLEM_STATUS = {
  UNSOLVED:  "unsolved",
  ATTEMPTED: "attempted",
  SOLVED:    "solved",
  SKIPPED:   "skipped",
  REVISIT:   "revisit",
} as const;
export type ProblemStatus = (typeof PROBLEM_STATUS)[keyof typeof PROBLEM_STATUS];

export const PROBLEM_STATUS_OPTIONS = [
  { label: "Unsolved",  value: PROBLEM_STATUS.UNSOLVED },
  { label: "Attempted", value: PROBLEM_STATUS.ATTEMPTED },
  { label: "Solved",    value: PROBLEM_STATUS.SOLVED },
  { label: "Skipped",   value: PROBLEM_STATUS.SKIPPED },
  { label: "Revisit",   value: PROBLEM_STATUS.REVISIT },
] as const;

// ─────────────────────────────────────────────

export const CODE_LANGUAGE = {
  PYTHON:     "python",
  JAVASCRIPT: "javascript",
  TYPESCRIPT: "typescript",
  GO:         "go",
  JAVA:       "java",
  CPP:        "cpp",
  RUST:       "rust",
} as const;
export type CodeLanguage = (typeof CODE_LANGUAGE)[keyof typeof CODE_LANGUAGE];

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

export const MODULE_TYPE = {
  LESSON:        "lesson",
  CODING:        "coding",
  QUIZ:          "quiz",
  SYSTEM_DESIGN: "system_design",
  LAB:           "lab",
} as const;
export type ModuleType = (typeof MODULE_TYPE)[keyof typeof MODULE_TYPE];

export const MODULE_TYPE_OPTIONS = [
  { label: "Lesson",        value: MODULE_TYPE.LESSON },
  { label: "Coding",        value: MODULE_TYPE.CODING },
  { label: "Quiz",          value: MODULE_TYPE.QUIZ },
  { label: "System Design", value: MODULE_TYPE.SYSTEM_DESIGN },
  { label: "Lab",           value: MODULE_TYPE.LAB },
] as const;

// ─────────────────────────────────────────────

export const COURSE_STATUS = {
  DRAFT:     "draft",
  PUBLISHED: "published",
  ARCHIVED:  "archived",
} as const;
export type CourseStatus = (typeof COURSE_STATUS)[keyof typeof COURSE_STATUS];

export const COURSE_STATUS_OPTIONS = [
  { label: "Draft",     value: COURSE_STATUS.DRAFT },
  { label: "Published", value: COURSE_STATUS.PUBLISHED },
  { label: "Archived",  value: COURSE_STATUS.ARCHIVED },
] as const;

// ─────────────────────────────────────────────

export const SORT_ORDER = {
  NEWEST:  "newest",
  OLDEST:  "oldest",
  POPULAR: "popular",
  AZ:      "az",
} as const;
export type SortOrder = (typeof SORT_ORDER)[keyof typeof SORT_ORDER];

export const SORT_ORDER_OPTIONS = [
  { label: "Newest",  value: SORT_ORDER.NEWEST },
  { label: "Oldest",  value: SORT_ORDER.OLDEST },
  { label: "Popular", value: SORT_ORDER.POPULAR },
  { label: "A → Z",   value: SORT_ORDER.AZ },
] as const;

// ─────────────────────────────────────────────

export const INTERVIEW_VERDICT = {
  STRONG_HIRE: "strong_hire",
  HIRE:        "hire",
  NO_HIRE:     "no_hire",
  STRONG_NO:   "strong_no_hire",
} as const;
export type InterviewVerdict = (typeof INTERVIEW_VERDICT)[keyof typeof INTERVIEW_VERDICT];

export const INTERVIEW_VERDICT_OPTIONS = [
  { label: "Strong Hire",    value: INTERVIEW_VERDICT.STRONG_HIRE },
  { label: "Hire",           value: INTERVIEW_VERDICT.HIRE },
  { label: "No Hire",        value: INTERVIEW_VERDICT.NO_HIRE },
  { label: "Strong No Hire", value: INTERVIEW_VERDICT.STRONG_NO },
] as const;

// ─────────────────────────────────────────────

export const LOAD_TEST_METHOD = {
  GET:    "GET",
  POST:   "POST",
  PUT:    "PUT",
  PATCH:  "PATCH",
  DELETE: "DELETE",
} as const;
export type LoadTestMethod = (typeof LOAD_TEST_METHOD)[keyof typeof LOAD_TEST_METHOD];

export const LOAD_TEST_METHOD_OPTIONS = [
  { label: "GET",    value: LOAD_TEST_METHOD.GET },
  { label: "POST",   value: LOAD_TEST_METHOD.POST },
  { label: "PUT",    value: LOAD_TEST_METHOD.PUT },
  { label: "PATCH",  value: LOAD_TEST_METHOD.PATCH },
  { label: "DELETE", value: LOAD_TEST_METHOD.DELETE },
] as const;

// ─────────────────────────────────────────────

export const USER_ROLE = {
  STUDENT:    "student",
  INSTRUCTOR: "instructor",
  MENTOR:     "mentor",
  ORG_ADMIN:  "admin",
} as const;
export type UserRole = (typeof USER_ROLE)[keyof typeof USER_ROLE];

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
export type QuestionType = (typeof QUESTION_TYPE)[keyof typeof QUESTION_TYPE];

export const QUESTION_TYPE_OPTIONS = [
  { label: "Multiple Choice", value: QUESTION_TYPE.MCQ },
  { label: "Coding",          value: QUESTION_TYPE.CODING },
] as const;

export const ASSESSMENT_DIFFICULTY = {
  BEGINNER:     "beginner",
  INTERMEDIATE: "intermediate",
  ADVANCED:     "advanced",
  EXPERT:       "expert",
} as const;
export type AssessmentDifficulty = (typeof ASSESSMENT_DIFFICULTY)[keyof typeof ASSESSMENT_DIFFICULTY];

export const ASSESSMENT_DIFFICULTY_OPTIONS = [
  { label: "Beginner",     value: ASSESSMENT_DIFFICULTY.BEGINNER },
  { label: "Intermediate", value: ASSESSMENT_DIFFICULTY.INTERMEDIATE },
  { label: "Advanced",     value: ASSESSMENT_DIFFICULTY.ADVANCED },
  { label: "Expert",       value: ASSESSMENT_DIFFICULTY.EXPERT },
] as const;

export const ASSESSMENT_STATUS = {
  DRAFT:     "draft",
  PUBLISHED: "published",
  SCHEDULED: "scheduled",
  ACTIVE:    "active",
  COMPLETED: "completed",
  ARCHIVED:  "archived",
} as const;
export type AssessmentStatus = (typeof ASSESSMENT_STATUS)[keyof typeof ASSESSMENT_STATUS];

export const ASSESSMENT_STATUS_OPTIONS = [
  { label: "Draft",     value: ASSESSMENT_STATUS.DRAFT },
  { label: "Published", value: ASSESSMENT_STATUS.PUBLISHED },
  { label: "Scheduled", value: ASSESSMENT_STATUS.SCHEDULED },
  { label: "Active",    value: ASSESSMENT_STATUS.ACTIVE },
  { label: "Completed", value: ASSESSMENT_STATUS.COMPLETED },
  { label: "Archived",  value: ASSESSMENT_STATUS.ARCHIVED },
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

export const ASSESSMENT_PARENT_TYPE_OPTIONS = [
  { label: "Standalone",          value: ASSESSMENT_PARENT_TYPE.STANDALONE },
  { label: "Course",              value: ASSESSMENT_PARENT_TYPE.COURSE },
  { label: "Module",              value: ASSESSMENT_PARENT_TYPE.MODULE },
  { label: "Roadmap",             value: ASSESSMENT_PARENT_TYPE.ROADMAP },
  { label: "Batch",               value: ASSESSMENT_PARENT_TYPE.BATCH },
  { label: "Bootcamp",            value: ASSESSMENT_PARENT_TYPE.BOOTCAMP },
  { label: "Hiring / Recruitment", value: ASSESSMENT_PARENT_TYPE.HIRING },
] as const;

export const ASSIGNEE_TYPE = {
  STUDENT: "student",
  BATCH:   "batch",
} as const;
export type AssigneeType = (typeof ASSIGNEE_TYPE)[keyof typeof ASSIGNEE_TYPE];

// ─────────────────────────────────────────────

export const EXPERIENCE_LEVEL = {
  BEGINNER:     "beginner",
  INTERMEDIATE: "intermediate",
  ADVANCED:     "advanced",
} as const;
export type ExperienceLevel = (typeof EXPERIENCE_LEVEL)[keyof typeof EXPERIENCE_LEVEL];

export const EXPERIENCE_LEVEL_OPTIONS = [
  { label: "Beginner",     value: EXPERIENCE_LEVEL.BEGINNER },
  { label: "Intermediate", value: EXPERIENCE_LEVEL.INTERMEDIATE },
  { label: "Advanced",     value: EXPERIENCE_LEVEL.ADVANCED },
] as const;

// ─────────────────────────────────────────────

export const SKILL_LEVEL = {
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

export const LEARNING_STYLE = {
  VIDEO:    "video",
  READING:  "reading",
  HANDS_ON: "hands_on",
  MIXED:    "mixed",
} as const;
export type LearningStyle = (typeof LEARNING_STYLE)[keyof typeof LEARNING_STYLE];

export const LEARNING_STYLE_OPTIONS = [
  { label: "Video",    value: LEARNING_STYLE.VIDEO },
  { label: "Reading",  value: LEARNING_STYLE.READING },
  { label: "Hands-On", value: LEARNING_STYLE.HANDS_ON },
  { label: "Mixed",    value: LEARNING_STYLE.MIXED },
] as const;

// ─────────────────────────────────────────────

export const LEARNING_GOAL = {
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

export const LEARNING_DOMAIN = {
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
export type LearningDomain = (typeof LEARNING_DOMAIN)[keyof typeof LEARNING_DOMAIN];

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

export const MODULE_CONTENT_TYPE = {
  VIDEO:      "video",
  PDF:        "pdf",
  NOTES:      "notes",
  ASSESSMENT: "assessment",
} as const;
export type ModuleContentType = (typeof MODULE_CONTENT_TYPE)[keyof typeof MODULE_CONTENT_TYPE];

export const MODULE_CONTENT_TYPE_OPTIONS = [
  { label: "Video",      value: MODULE_CONTENT_TYPE.VIDEO },
  { label: "PDF",        value: MODULE_CONTENT_TYPE.PDF },
  { label: "Notes",      value: MODULE_CONTENT_TYPE.NOTES },
  { label: "Assessment", value: MODULE_CONTENT_TYPE.ASSESSMENT },
] as const;

// ─────────────────────────────────────────────

export const COURSE_DIFFICULTY = {
  BEGINNER:     "beginner",
  INTERMEDIATE: "intermediate",
  ADVANCED:     "advanced",
} as const;
export type CourseDifficulty = (typeof COURSE_DIFFICULTY)[keyof typeof COURSE_DIFFICULTY];

export const COURSE_DIFFICULTY_OPTIONS = [
  { label: "Beginner",     value: COURSE_DIFFICULTY.BEGINNER },
  { label: "Intermediate", value: COURSE_DIFFICULTY.INTERMEDIATE },
  { label: "Advanced",     value: COURSE_DIFFICULTY.ADVANCED },
] as const;

// ─────────────────────────────────────────────
// Practice / AI Interview Prep (Phase 8)
// ─────────────────────────────────────────────

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

export const PRACTICE_TECHNOLOGY_OPTIONS = [
  { label: "Go",              value: "Go" },
  { label: "Python",          value: "Python" },
  { label: "JavaScript",      value: "JavaScript" },
  { label: "TypeScript",      value: "TypeScript" },
  { label: "Java",            value: "Java" },
  { label: "Rust",            value: "Rust" },
  { label: "C++",             value: "C++" },
  { label: "React",           value: "React" },
  { label: "Next.js",         value: "Next.js" },
  { label: "Node.js",         value: "Node.js" },
  { label: "PostgreSQL",      value: "PostgreSQL" },
  { label: "Redis",           value: "Redis" },
  { label: "Docker",          value: "Docker" },
  { label: "Kubernetes",      value: "Kubernetes" },
  { label: "AWS",             value: "AWS" },
  { label: "System Design",   value: "System Design" },
  { label: "Data Structures", value: "Data Structures" },
  { label: "Algorithms",      value: "Algorithms" },
  { label: "GraphQL",         value: "GraphQL" },
  { label: "REST APIs",       value: "REST APIs" },
  { label: "Microservices",   value: "Microservices" },
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
