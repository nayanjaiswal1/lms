// ─────────────────────────────────────────────
// FEATURE KEYS
// Typed constants for every feature the platform has.
// Never use raw strings — always FEATURES.X.
// ─────────────────────────────────────────────

export const FEATURES = {
  // Auth methods
  SOCIAL_AUTH:       'social_auth',
  MAGIC_LINK:        'magic_link',

  // Core learning
  CODING_PROBLEMS:   'coding_problems',
  QUIZZES:           'quizzes',
  ASSESSMENTS:       'assessments',
  FLASHCARDS:        'flashcards',
  CERTIFICATES:      'certificates',
  AI_FEATURES:       'ai_features',

  // Collaboration
  MENTORS:           'mentors',
  WIKI:              'wiki',

  // Advanced tools
  SYSTEM_DESIGN:     'system_design',
  INTERVIEW_BOARD:   'interview_board',
  LOAD_TEST:         'load_test',
  SHEET_TRACKER:     'sheet_tracker',

  // Platform
  PAYMENTS:          'payments',
  ANONYMOUS_TESTS:   'anonymous_tests',
  MULTI_ORG:         'multi_org',
  PROFILE:           'profile',

  // Phase 5–8
  COURSES:           'courses',
  PRACTICE_AI:       'practice_ai',
  BATCH_CHAT:        'batch_chat',
} as const;

export type Feature = (typeof FEATURES)[keyof typeof FEATURES];

// ─────────────────────────────────────────────
// PLAN TIERS
// Used for display (billing page, upgrade prompts)
// and by the BACKEND to resolve entitlements.
// Frontend components NEVER compare plan tier
// to decide if a feature is accessible.
// ─────────────────────────────────────────────

export const PLANS = {
  FREE:       'free',
  PRO:        'pro',
  ENTERPRISE: 'enterprise',
} as const;

export type Plan = (typeof PLANS)[keyof typeof PLANS];

// ─────────────────────────────────────────────
// LOCKED FEATURE INFO
// The backend tells the frontend HOW to unlock
// each feature the user currently can't access.
// The frontend shows the right CTA without
// knowing whether it's a plan upgrade or add-on.
// ─────────────────────────────────────────────

export type UnlockVia = 'plan' | 'addon' | 'plan_or_addon';

export interface LockedFeatureInfo {
  unlock_via:    UnlockVia;
  // Human-readable label for the upgrade/add-on button
  cta_label:     string;
  // Short reason shown in the lock overlay
  reason:        string;
}

// ─────────────────────────────────────────────
// FEATURE DISPLAY METADATA
// Names and descriptions used in lock overlays
// and billing pages. The single source for labels.
// ─────────────────────────────────────────────

export const FEATURE_META: Record<Feature, { label: string; description: string }> = {
  social_auth:      { label: 'Social Login',       description: 'Sign in with Google, GitHub, or Microsoft' },
  magic_link:       { label: 'Magic Link',          description: 'Passwordless email login' },
  coding_problems:  { label: 'Coding Problems',     description: 'In-browser coding challenges with test cases' },
  quizzes:          { label: 'Quizzes',             description: 'AI-generated module quizzes' },
  assessments:      { label: 'Assessments',         description: 'Proctored MCQ & coding tests with auto-grading and analytics' },
  flashcards:       { label: 'Flashcards',          description: 'Spaced repetition review cards' },
  certificates:     { label: 'Certificates',        description: 'Verifiable completion certificates' },
  ai_features:      { label: 'AI Features',         description: 'AI-generated curriculum, quizzes, and revision plans' },
  mentors:          { label: 'Mentors',             description: 'Mentor assignment and chat' },
  wiki:             { label: 'Wiki',                description: 'Collaborative org knowledge base' },
  system_design:    { label: 'System Design',       description: 'Drag-and-drop architecture canvas' },
  interview_board:  { label: 'Interview Board',     description: 'Live coding interviews with real-time shared editor' },
  load_test:        { label: 'Load Test Simulator', description: 'Real HTTP load testing and canvas traffic simulation' },
  sheet_tracker:    { label: 'Sheet Tracker',       description: 'Multi-sheet problem tracker with overlap view' },
  payments:         { label: 'Payments',            description: 'Paid course enrollment via Stripe / Razorpay' },
  anonymous_tests:  { label: 'Anonymous Tests',     description: 'Public tests with no login required' },
  multi_org:        { label: 'Multi-Org',           description: 'Belong to and switch between multiple organizations' },
  profile:          { label: 'Learning Profile',    description: 'Public learning identity with skills, achievements, and statistics' },
  courses:          { label: 'Courses',             description: 'Video, PDF, and notes-based course content with progress tracking' },
  practice_ai:      { label: 'AI Interview Prep',  description: 'AI-generated interview questions with personalised feedback' },
  batch_chat:       { label: 'Batch Chat',          description: 'Mentor–student messaging within cohort batches' },
};
