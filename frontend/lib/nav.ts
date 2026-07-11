import {
  LayoutDashboard,
  BookOpen,
  Brain,
  MessageSquare,
  Award,
  FileText,
  Layers,
  Video,
  Activity,
  ListChecks,
  ClipboardCheck,
  FileQuestion,
  Users,
  User,
  GraduationCap,
  Shield,
  UserCheck,
  Ticket,
  BookmarkCheck,
  Calendar,
  Compass,
  type LucideIcon,
} from "lucide-react";
import ROUTES from "@/lib/routes";
import { FEATURES, type Feature } from "@/lib/features";
import { usePermissions } from "@/lib/auth/permissions";

// ─────────────────────────────────────────────
// Nav item shape
// `feature`          — if present, item is wrapped in <AccessGate> automatically.
// `requiredPermission` — RBAC permission code; item hidden unless user holds it.
// `mode`             — how to gate: badge (show with badge), hide (remove entirely).
// ─────────────────────────────────────────────

export interface NavItem {
  label:               string;
  href:                string;
  icon:                LucideIcon;
  feature?:            Feature;
  requiredPermission?: string;
  mode?:               "badge" | "hide";
  exact?:              boolean;
}

export interface NavGroup {
  label?: string;
  items:  NavItem[];
}

// ─────────────────────────────────────────────
// TOP NAVBAR (public + auth-aware)
// ─────────────────────────────────────────────

export const TOP_NAV: NavItem[] = [
  { label: "Courses", href: ROUTES.COURSES, icon: BookOpen },
  { label: "Sheets",  href: ROUTES.SHEETS,  icon: ListChecks, feature: FEATURES.SHEET_TRACKER, mode: "hide" },
];

// ─────────────────────────────────────────────
// SETTINGS SIDEBAR
// ─────────────────────────────────────────────

export const SETTINGS_NAV: NavGroup[] = [
  {
    label: "Account",
    items: [
      { label: "Profile", href: ROUTES.SETTINGS_PROFILE, icon: User, exact: true },
    ],
  },
];

// ─────────────────────────────────────────────
// ALL NAV ITEMS — permission-keyed catalogue
//
// The sidebar renders items from this map filtered by the current user's
// effective RBAC permissions. No role names ever appear here.
// The backend returns permission codes; the frontend renders only items
// whose requiredPermission is in that set.
// ─────────────────────────────────────────────

export const ALL_NAV_ITEMS: Record<string, NavItem> = {
  dashboard: {
    label: "Dashboard",
    href:  ROUTES.DASHBOARD,
    icon:  LayoutDashboard,
    exact: true,
  },
  what_now: {
    label:   "What Now?",
    href:    ROUTES.NOW,
    icon:    Compass,
    feature: FEATURES.WHAT_NOW,
    mode:    "hide",
    exact:   true,
  },
  courses: {
    label:               "My Courses",
    href:                ROUTES.COURSES,
    icon:                GraduationCap,
    feature:             FEATURES.COURSES,
    requiredPermission:  "courses.view",
    mode:                "badge",
  },
  practice: {
    label:               "Practice",
    href:                ROUTES.PRACTICE,
    icon:                Brain,
    feature:             FEATURES.PRACTICE_AI,
    requiredPermission:  "practice.use",
    mode:                "badge",
  },
  assessments: {
    label:               "Assessments",
    href:                ROUTES.ASSESSMENTS,
    icon:                ClipboardCheck,
    feature:             FEATURES.ASSESSMENTS,
    requiredPermission:  "assessments.take",
    mode:                "badge",
  },
  mentors: {
    label: "Mentors",
    href:  ROUTES.MENTORS,
    icon:  UserCheck,
  },
  calendar: {
    label: "Calendar",
    href:  ROUTES.CALENDAR,
    icon:  Calendar,
  },
  highlights: {
    label: "Saved Highlights",
    href:  ROUTES.HIGHLIGHTS,
    icon:  BookmarkCheck,
  },
  flashcards: {
    label:               "Review Cards",
    href:                ROUTES.REVIEW,
    icon:                Brain,
    feature:             FEATURES.FLASHCARDS,
    requiredPermission:  "content.srs",
    mode:                "badge",
  },
  sheet_tracker: {
    label:               "Sheet Tracker",
    href:                ROUTES.SHEETS,
    icon:                ListChecks,
    feature:             FEATURES.SHEET_TRACKER,
    requiredPermission:  "content.sheets",
    mode:                "badge",
  },
  mentor_chat: {
    label:               "Mentor Chat",
    href:                ROUTES.MENTORING,
    icon:                MessageSquare,
    feature:             FEATURES.MENTORS,
    requiredPermission:  "mentoring.chat",
    mode:                "badge",
  },
  certificates: {
    label:               "Certificates",
    href:                ROUTES.CERTIFICATES,
    icon:                Award,
    feature:             FEATURES.CERTIFICATES,
    requiredPermission:  "content.certificates",
    mode:                "badge",
  },
  wiki: {
    label:               "Wiki",
    href:                ROUTES.WIKI,
    icon:                FileText,
    feature:             FEATURES.WIKI,
    requiredPermission:  "content.wiki",
    mode:                "badge",
  },
  system_design: {
    label:               "System Design",
    href:                ROUTES.DESIGN,
    icon:                Layers,
    feature:             FEATURES.SYSTEM_DESIGN,
    requiredPermission:  "content.system_design",
    mode:                "badge",
  },
  interview_board: {
    label:               "Interview Board",
    href:                ROUTES.INTERVIEW,
    icon:                Video,
    feature:             FEATURES.INTERVIEW_BOARD,
    requiredPermission:  "content.interview_board",
    mode:                "badge",
  },
  load_test: {
    label:               "Load Test",
    href:                ROUTES.LOAD_TEST,
    icon:                Activity,
    feature:             FEATURES.LOAD_TEST,
    requiredPermission:  "content.load_test",
    mode:                "badge",
  },
  instructor_dashboard: {
    label:               "Courses",
    href:                ROUTES.MANAGE_COURSES,
    icon:                BookOpen,
    requiredPermission:  "courses.create",
  },
  instructor_courses: {
    label:               "My Courses",
    href:                ROUTES.MANAGE_COURSES,
    icon:                BookOpen,
    requiredPermission:  "courses.create",
  },
  instructor_assessments: {
    label:               "Assessments",
    href:                ROUTES.MANAGE_ASSESSMENTS,
    icon:                ClipboardCheck,
    feature:             FEATURES.ASSESSMENTS,
    requiredPermission:  "assessments.create",
    mode:                "badge",
  },
  question_bank: {
    label:               "Question Bank",
    href:                ROUTES.QUESTION_BANK,
    icon:                FileQuestion,
    feature:             FEATURES.ASSESSMENTS,
    requiredPermission:  "assessments.manage_questions",
    mode:                "badge",
  },
  batches: {
    label:               "Batches",
    href:                ROUTES.BATCHES,
    icon:                Users,
    feature:             FEATURES.ASSESSMENTS,
    requiredPermission:  "assessments.manage_batches",
    mode:                "badge",
  },
  mentor_dashboard: {
    label:               "Overview",
    href:                ROUTES.MENTORING,
    icon:                LayoutDashboard,
    requiredPermission:  "mentoring.manage_batches",
    exact:               true,
  },
  mentor_messages: {
    label:               "Messages",
    href:                ROUTES.MENTORING_MESSAGES,
    icon:                MessageSquare,
    requiredPermission:  "mentoring.manage_batches",
  },
  mentor_batches: {
    label:               "My Batches",
    href:                ROUTES.BATCHES,
    icon:                Users,
    feature:             FEATURES.BATCH_CHAT,
    requiredPermission:  "mentoring.manage_batches",
    mode:                "badge",
  },
  mentor_tickets: {
    label:               "Ticket Queue",
    href:                ROUTES.MENTORING_TICKETS,
    icon:                Ticket,
    requiredPermission:  "mentoring.manage_batches",
  },

  admin_rbac: {
    label:               "Roles & Permissions",
    href:                ROUTES.ADMIN_RBAC_ROLES,
    icon:                Shield,
    requiredPermission:  "admin.manage_roles",
  },
  admin_users: {
    label:               "Users",
    href:                ROUTES.ADMIN_RBAC_USERS,
    icon:                Users,
    requiredPermission:  "admin.view_members",
  },

};

// ─────────────────────────────────────────────
// MAIN NAV GROUPS — full sidebar structure.
//
// The Sidebar component filters out items whose `requiredPermission` the
// current user does not hold, then drops any group that becomes empty.
// Groups and items are defined once here; no role names appear anywhere.
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
// VISIBLE NAV GROUPS — shared filtering logic.
//
// Used by both the desktop sidebar and the mobile drawer/bottom-nav so
// permission filtering lives in exactly one place.
// ─────────────────────────────────────────────

export function useVisibleNavGroups(): NavGroup[] {
  const perms = usePermissions();

  return MAIN_NAV_GROUPS.map((group) => ({
    ...group,
    items: group.items.filter(
      (item) => !item.requiredPermission || perms.has(item.requiredPermission),
    ),
  })).filter((group) => group.items.length > 0);
}

export const MAIN_NAV_GROUPS: NavGroup[] = [
  {
    items: [
      ALL_NAV_ITEMS.dashboard,
      ALL_NAV_ITEMS.what_now,
      ALL_NAV_ITEMS.courses,
      ALL_NAV_ITEMS.practice,
      ALL_NAV_ITEMS.assessments,
      ALL_NAV_ITEMS.mentors,
      ALL_NAV_ITEMS.calendar,
      ALL_NAV_ITEMS.highlights,
      ALL_NAV_ITEMS.flashcards,
      ALL_NAV_ITEMS.sheet_tracker,
      ALL_NAV_ITEMS.mentor_chat,
      ALL_NAV_ITEMS.certificates,
      ALL_NAV_ITEMS.wiki,
      ALL_NAV_ITEMS.system_design,
      ALL_NAV_ITEMS.interview_board,
      ALL_NAV_ITEMS.load_test,
    ],
  },
  {
    label: "Teaching",
    items: [
      ALL_NAV_ITEMS.instructor_courses,
      ALL_NAV_ITEMS.instructor_assessments,
      ALL_NAV_ITEMS.question_bank,
      ALL_NAV_ITEMS.batches,
    ],
  },
  {
    label: "Mentoring",
    items: [
      ALL_NAV_ITEMS.mentor_dashboard,
      ALL_NAV_ITEMS.mentor_messages,
      ALL_NAV_ITEMS.mentor_batches,
      ALL_NAV_ITEMS.mentor_tickets,
    ],
  },
  {
    label: "Administration",
    items: [
      ALL_NAV_ITEMS.admin_rbac,
      ALL_NAV_ITEMS.admin_users,
    ],
  },
];
