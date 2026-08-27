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
  INTERVIEW_EXP:     'interview_exp',

  // Platform
  PAYMENTS:          'payments',
  ANONYMOUS_TESTS:   'anonymous_tests',
  MULTI_ORG:         'multi_org',
  PROFILE:           'profile',

  // Phase 5–8
  COURSES:           'courses',
  PRACTICE_AI:       'practice_ai',
  BATCH_CHAT:        'batch_chat',

  // Personal — no org/plan concept, gated by direct per-user grant
  WHAT_NOW:          'what_now',

  // Nightly AI revision digest — per-user opt-in beta via direct permission
  // grant, same shape as WHAT_NOW above (no unlock path to advertise).
  REVISION_DIGEST:   'revision_digest',

  // GitLab integration — inert until an org admin connects an installation
  GITLAB_INTEGRATION: 'gitlab_integration',

  // AI Connector (MCP) — org-admin togglable, defaults on
  AI_CONNECTOR: 'ai_connector',

  // Mentor session booking — org-admin togglable, defaults on. What a
  // student may do with it is bounded by their credit balance and the org's
  // booking policy, not by an entitlement.
  SESSION_BOOKING: 'session_booking',

  // Lesson compiler bottom-dock — code-level toggle (see alwaysOrgEnabled in
  // backend/internal/features/service.go), no admin UI yet
  LESSON_COMPILER_BOTTOM_DOCK: 'lesson_compiler_bottom_dock',
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
// PLAN TIER DISPLAY
// UI-only — there is no plan/entitlement/payment
// backend yet (every feature is currently free for
// every org, see internal/features/service.go).
// Pro/Enterprise are presentational placeholders,
// not tied to any real feature gate or price.
// ─────────────────────────────────────────────

export interface PlanTierMeta {
  id: Plan;
  name: string;
  price: string;
  tagline: string;
  cta: string;
  ctaDisabled: boolean;
}

export const PLAN_TIERS: PlanTierMeta[] = [
  {
    id: PLANS.FREE,
    name: "Free",
    price: "$0",
    tagline: "Everything included while we're in beta.",
    cta: "Current plan",
    ctaDisabled: true,
  },
  {
    id: PLANS.PRO,
    name: "Pro",
    price: "Contact us",
    tagline: "For growing teams that need more seats and support.",
    cta: "Coming soon",
    ctaDisabled: true,
  },
  {
    id: PLANS.ENTERPRISE,
    name: "Enterprise",
    price: "Contact us",
    tagline: "For large organizations with custom requirements.",
    cta: "Coming soon",
    ctaDisabled: true,
  },
];

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
  interview_exp:    { label: 'Interview Experiences', description: 'Crowd-sourced company/position interview Q&A with voting and nested discussion' },
  payments:         { label: 'Payments',            description: 'Paid course enrollment via Stripe / Razorpay' },
  anonymous_tests:  { label: 'Anonymous Tests',     description: 'Public tests with no login required' },
  multi_org:        { label: 'Multi-Org',           description: 'Belong to and switch between multiple organizations' },
  profile:          { label: 'Learning Profile',    description: 'Public learning identity with skills, achievements, and statistics' },
  courses:          { label: 'Courses',             description: 'Video, PDF, and notes-based course content with progress tracking' },
  practice_ai:      { label: 'AI Interview Prep',  description: 'AI-generated interview questions with personalised feedback' },
  batch_chat:       { label: 'Batch Chat',          description: 'Mentor–student messaging within cohort batches' },
  what_now:         { label: 'What Now?',           description: 'A single-question room for deciding what to work on next' },
  revision_digest:  { label: 'Revision Digest',     description: 'Nightly AI-written recap of your notes, mistakes, sheet progress, and due flashcards, emailed once a day' },
  gitlab_integration: { label: 'GitLab Integration', description: 'Connect your GitLab account and your organization\'s GitLab instance' },
  ai_connector:     { label: 'AI Connector',        description: 'Connect your own Claude or ChatGPT to read lessons, save notes, and manage your calendar via MCP' },
  session_booking:  { label: 'Session Booking',     description: 'Book 1:1 and cohort mentor sessions against published availability, with session credits and cancellation rules' },
  lesson_compiler_bottom_dock: { label: 'Lesson Compiler Bottom Dock', description: 'Allow the lesson scratch compiler to dock to the bottom of the screen, not just the right side' },
};
