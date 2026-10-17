import {
  LayoutDashboard,
  BookOpen,
  Brain,
  MessageSquare,
  FileText,
  ListChecks,
  ClipboardCheck,
  FileQuestion,
  Users,
  User,
  GraduationCap,
  Bug,
  Wrench,
  Shield,
  UserCheck,
  Ticket,
  LifeBuoy,
  BookmarkCheck,
  Calendar,
  Map,
  FolderTree,
  FolderGit2,
  Briefcase,
  Bot,
  TicketPercent,
  Lock,
  Flag,
  Building2,
  NotebookPen,
  Inbox,
  PenLine,
  Binary,
  BarChart3,
  RefreshCw,
  Library,
  Presentation,
  CreditCard,
  type LucideIcon,
} from "lucide-react";
import ROUTES from "@/lib/routes";
import { FEATURES, type Feature } from "@/lib/features";
import { ACCESS, PERMISSIONS } from "@/lib/auth/permission-codes";
import { usePermissions } from "@/lib/auth/permissions";
import { isPermitted } from "@/lib/auth/permission-filter";
import { PLATFORM_NAV_GROUPS } from "@/lib/platform-nav";
import { useTerminology } from "@/lib/terminology-context";
import { type Terminology } from "@/lib/terminology";

// ─────────────────────────────────────────────
// Nav item shape
// `feature`          — if present, item is wrapped in <AccessGate> automatically.
// `requiredPermission` — RBAC permission code(s); item hidden unless the user
//                       holds it. An array is an any-of check (e.g. a hub
//                       entry that should show if the user can reach any one
//                       of the pages it links to).
// `hideForPermission`  — inverse of the above; item hidden if user holds it (or,
//                       for an array, ANY of them) — e.g. the learner-facing
//                       mentor directory is hidden from instructors, mentors
//                       and admins, who have their own mentoring surfaces.
// `hub`              — entry point to a hub page: visible only if at least one
//                       of the hub's own items is visible to the user.
// `mode`             — how to gate: badge (show with badge), hide (remove entirely).
// `hideFromBottomNav` — item stays in the sidebar/drawer but never occupies
//                       one of the 4 mobile bottom-nav slots (e.g. Help &
//                       Support — reachable via the Menu drawer instead).
// ─────────────────────────────────────────────

interface NavItem {
  label:               string;
  href:                string;
  icon:                LucideIcon;
  feature?:            Feature;
  requiredPermission?: string | string[];
  hideForPermission?:  string | string[];
  hub?:                () => NavGroup[];
  mode?:               "badge" | "hide";
  exact?:              boolean;
  hideFromBottomNav?:  boolean;
}

export interface NavGroup {
  label?: string;
  items:  NavItem[];
}

// ─────────────────────────────────────────────
// SETTINGS SIDEBAR
// ─────────────────────────────────────────────

export const SETTINGS_NAV: NavGroup[] = [
  {
    label: "Account",
    items: [
      { label: "Profile",      href: ROUTES.SETTINGS_PROFILE,      icon: User,   exact: true },
      { label: "Security",     href: ROUTES.SETTINGS_SECURITY,     icon: Shield, exact: true },
      { label: "Privacy",      href: ROUTES.SETTINGS_PRIVACY,      icon: Lock,   exact: true },
      { label: "Integrations", href: ROUTES.SETTINGS_INTEGRATIONS, icon: Bot,    exact: true },
      // public: every signed-in user sees their own plan, entitlements and usage.
      { label: "Billing",      href: ROUTES.BILLING,               icon: CreditCard, exact: true },
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
  // public: every signed-in user lands here; it only shows what they can access.
  dashboard: {
    label: "Dashboard",
    href:  ROUTES.DASHBOARD,
    icon:  LayoutDashboard,
    exact: true,
  },
  courses: {
    label:               "My Courses",
    href:                ROUTES.COURSES,
    icon:                GraduationCap,
    feature:             FEATURES.COURSES,
    requiredPermission:  PERMISSIONS.COURSES.VIEW,
    mode:                "badge",
  },
  interview_prep: {
    label:               "Interview Prep",
    href:                ROUTES.INTERVIEW_PREP,
    icon:                ClipboardCheck,
    feature:             FEATURES.PRACTICE_AI,
    requiredPermission:  PERMISSIONS.PRACTICE.USE,
    mode:                "badge",
  },
  labs: {
    label:              "Labs",
    href:               ROUTES.LABS_CATALOG,
    icon:               Bug,
    requiredPermission: [...ACCESS.LABS],
  },
  roadmap: {
    label:              "Roadmap",
    href:               ROUTES.ROADMAP,
    icon:               Map,
    requiredPermission: [...ACCESS.PRACTICE],
  },
  assessments: {
    label:               "Assessments",
    href:                ROUTES.ASSESSMENTS,
    icon:                ClipboardCheck,
    feature:             FEATURES.ASSESSMENTS,
    requiredPermission:  PERMISSIONS.ASSESSMENTS.TAKE,
    mode:                "badge",
  },
  mentors: {
    label:              "Mentors",
    href:               ROUTES.MENTORS,
    icon:               UserCheck,
    requiredPermission: PERMISSIONS.MENTORING.CHAT,
    // Learner directory only: instructors, mentors and admins have their own
    // mentoring surfaces.
    hideForPermission:  [
      PERMISSIONS.MENTORING.VIEW_TICKETS,
      PERMISSIONS.MENTORING.MANAGE_BATCHES,
      PERMISSIONS.ADMIN.MANAGE_ROLES,
    ],
  },
  // public: every signed-in user can raise a ticket.
  support: {
    label:  "Help & Support",
    href:   ROUTES.SUPPORT,
    icon:   LifeBuoy,
    hideFromBottomNav: true,
    exact: true,
  },
  support_queue: {
    label:              "Support Queue",
    href:               ROUTES.SUPPORT_QUEUE,
    icon:               Inbox,
    requiredPermission: PERMISSIONS.SUPPORT.MANAGE,
  },
  learn_hub: {
    label: "Learn",
    href:  ROUTES.LEARN,
    icon:  BookOpen,
    hub:   () => LEARN_HUB_GROUPS,
  },
  teach_hub: {
    label:              "Instructor",
    href:               ROUTES.TEACH,
    icon:               Presentation,
    requiredPermission: [...ACCESS.TEACH_HUB],
  },
  calendar: {
    label:              "Calendar",
    href:               ROUTES.CALENDAR,
    icon:               Calendar,
    requiredPermission: [...ACCESS.CALENDAR],
  },
  highlights: {
    label:              "Saved Highlights",
    href:               ROUTES.HIGHLIGHTS,
    icon:               BookmarkCheck,
    requiredPermission: [...ACCESS.PRACTICE],
  },
  review: {
    label:              "Revision",
    href:               ROUTES.REVIEW,
    icon:               RefreshCw,
    requiredPermission: PERMISSIONS.CONTENT.SRS,
  },
  mistakes: {
    label:              "My Mistakes",
    href:               ROUTES.MISTAKES,
    icon:               Brain,
    requiredPermission: PERMISSIONS.PRACTICE.USE,
  },
  algo_visualizer: {
    label:              "Algorithm Visualizer",
    href:               ROUTES.ALGO_VISUALIZER,
    icon:               Binary,
    requiredPermission: [...ACCESS.PRACTICE],
  },
  sheet_tracker: {
    label:               "Sheet Tracker",
    href:                ROUTES.SHEETS,
    icon:                ListChecks,
    feature:             FEATURES.SHEET_TRACKER,
    requiredPermission:  PERMISSIONS.CONTENT.SHEETS,
    mode:                "badge",
  },
  learning_journal: {
    label:               "Learning Journal",
    href:                ROUTES.JOURNAL,
    icon:                NotebookPen,
    requiredPermission:  PERMISSIONS.CONTENT.LEARNING_JOURNAL,
    mode:                "badge",
  },
  captures: {
    label:               "Captures",
    href:                ROUTES.CAPTURES,
    icon:                Inbox,
    requiredPermission:  PERMISSIONS.CONTENT.CAPTURES,
    mode:                "badge",
  },
  diary: {
    label:               "Diary",
    href:                ROUTES.DIARY,
    icon:                PenLine,
    requiredPermission:  PERMISSIONS.CONTENT.DIARY,
    mode:                "badge",
  },
  wiki: {
    label:               "Wiki",
    href:                ROUTES.WIKI,
    icon:                FileText,
    feature:             FEATURES.WIKI,
    requiredPermission:  PERMISSIONS.CONTENT.WIKI,
    mode:                "badge",
  },
  interview_exp: {
    label:               "Interview Experiences",
    href:                ROUTES.INTERVIEW_EXP,
    icon:                MessageSquare,
    feature:             FEATURES.INTERVIEW_EXP,
    requiredPermission:  PERMISSIONS.CONTENT.INTERVIEW_EXP,
    mode:                "badge",
  },
  // system_design / interview_board / load_test nav items removed: those
  // routes (/design, /interview, /load-test) have no page.tsx yet. Re-add
  // once each ships. FEATURES.SYSTEM_DESIGN etc. stay defined — still used
  // by the in-course design canvas (components/courses/design-canvas.tsx).
  instructor_assessments: {
    label:               "Assessments",
    href:                ROUTES.ASSESSMENTS,
    icon:                ClipboardCheck,
    feature:             FEATURES.ASSESSMENTS,
    requiredPermission:  PERMISSIONS.ASSESSMENTS.CREATE,
    mode:                "badge",
  },
  question_bank: {
    label:               "Question Bank",
    href:                ROUTES.QUESTION_BANK,
    icon:                FileQuestion,
    feature:             FEATURES.ASSESSMENTS,
    requiredPermission:  PERMISSIONS.ASSESSMENTS.MANAGE_QUESTIONS,
    mode:                "badge",
  },
  cohort_groups: {
    label:               "Batches",
    href:                ROUTES.COHORT_GROUPS,
    icon:                FolderTree,
    feature:             FEATURES.ASSESSMENTS,
    requiredPermission:  PERMISSIONS.ASSESSMENTS.MANAGE_BATCHES,
    mode:                "badge",
  },
  cohorts: {
    label:               "Cohorts",
    href:                ROUTES.WORKSPACES_COHORTS,
    icon:                FolderGit2,
    feature:             FEATURES.GITLAB_INTEGRATION,
    requiredPermission:  PERMISSIONS.PROJECTS.MANAGE,
    mode:                "hide",
  },
  // Gated on projects.view, not projects.create: creating a workspace needs
  // create, but anyone who can view can be invited into someone else's
  // workspace — the create button on /workspaces is what's gated on create.
  workspaces: {
    label:              "Workspaces",
    href:               ROUTES.WORKSPACES,
    icon:               Briefcase,
    requiredPermission: PERMISSIONS.PROJECTS.VIEW,
  },
  mentor_dashboard: {
    label:               "Overview",
    href:                ROUTES.MENTORING,
    icon:                LayoutDashboard,
    requiredPermission:  PERMISSIONS.MENTORING.MANAGE_BATCHES,
    exact:               true,
  },
  mentor_tickets: {
    label:               "Ticket Queue",
    href:                ROUTES.MENTORING_TICKETS,
    icon:                Ticket,
    requiredPermission:  PERMISSIONS.MENTORING.VIEW_TICKETS,
  },
  // Sidebar copy of the ticket queue, for mentors (manage_batches). Instructors
  // hold view_tickets but not manage_batches and reach the queue via the Teach hub.
  mentor_tickets_nav: {
    label:               "Ticket Queue",
    href:                ROUTES.MENTORING_TICKETS,
    icon:                Ticket,
    requiredPermission:  PERMISSIONS.MENTORING.MANAGE_BATCHES,
  },

  admin_rbac: {
    label:               "Roles & Permissions",
    href:                ROUTES.ADMIN_RBAC_ROLES,
    icon:                Shield,
    requiredPermission:  PERMISSIONS.ADMIN.MANAGE_ROLES,
  },
  admin_users: {
    label:               "Users",
    href:                ROUTES.USERS,
    icon:                Users,
    requiredPermission:  PERMISSIONS.ADMIN.VIEW_MEMBERS,
  },
  admin_coupons: {
    label:               "Coupons",
    href:                ROUTES.ADMIN_COUPONS,
    icon:                TicketPercent,
    requiredPermission:  PERMISSIONS.PAYMENTS.MANAGE_COUPONS,
  },
  admin_content_reports: {
    label:               "Content Reports",
    href:                ROUTES.ADMIN_CONTENT_REPORTS,
    icon:                Flag,
    requiredPermission:  PERMISSIONS.MODERATION.MANAGE,
  },
  org_settings: {
    label:               "Organization Settings",
    href:                ROUTES.ORG_SETTINGS,
    icon:                Building2,
    requiredPermission:  PERMISSIONS.ADMIN.MANAGE_ORG,
  },

  manage_courses: {
    label:               "Courses",
    href:                ROUTES.COURSE_NEW,
    icon:                GraduationCap,
    feature:             FEATURES.COURSES,
    requiredPermission:  PERMISSIONS.COURSES.CREATE,
    mode:                "badge",
  },
  course_analytics: {
    label:               "Course Analytics",
    href:                ROUTES.TEACH_ANALYTICS,
    icon:                BarChart3,
    feature:             FEATURES.COURSES,
    requiredPermission:  PERMISSIONS.COURSES.VIEW_ANALYTICS,
    mode:                "badge",
  },

  lab_builder: {
    label:               "Create Debug Lab",
    href:                ROUTES.LAB_BUILDER,
    icon:                Wrench,
    requiredPermission:  PERMISSIONS.LABAUTHOR.COMPOSE,
  },
  lab_library: {
    label:               "Lab library",
    href:                ROUTES.LABS_CATALOG,
    icon:                Bug,
    requiredPermission:  PERMISSIONS.LABAUTHOR.COMPOSE,
  },
  library: {
    label:               "Library",
    href:                ROUTES.LIBRARY,
    icon:                Library,
    requiredPermission:  PERMISSIONS.COURSES.EDIT,
  },
};

// ─────────────────────────────────────────────
// VISIBLE NAV GROUPS — shared filtering logic.
//
// Used by the desktop sidebar, the mobile drawer/bottom-nav and both hub pages
// so permission filtering lives in exactly one place.
// ─────────────────────────────────────────────

// Nav items whose label carries the word "Batch"/"Batches" — the org-flavored
// noun (Class/Cohort/Team depending on org type). A word-boundary replace
// (not a full label swap) so prefixed labels like "My Batches" keep their
// "My " and become "My Classes". Scoped to the batch/instructor items only:
// the separate 1:1 mentoring-ticket system (ROUTES.MENTORS directory, and the
// per-ticket chat reached from a mentor's profile) is a distinct support
// feature, not the class-teacher concept, so it keeps its own wording.
const BATCH_LABEL_HREFS = new Set<string>([ROUTES.COHORT_GROUPS]);

function applyTerminology(label: string, t: Terminology): string {
  return label.replace(/\bBatches\b/g, t.classPlural).replace(/\bBatch\b/g, t.class_);
}

// Pure: permission + hub + terminology filtering, then drops empty groups.
export function filterNavGroups(
  groups: NavGroup[],
  perms: ReadonlySet<string>,
  t: Terminology,
): NavGroup[] {
  return groups
    .map((group) => ({
      ...group,
      items: group.items
        .filter((item) => isPermitted(item, perms))
        .filter((item) => !item.hub || filterNavGroups(item.hub(), perms, t).length > 0)
        .map((item) =>
          BATCH_LABEL_HREFS.has(item.href) ? { ...item, label: applyTerminology(item.label, t) } : item,
        ),
    }))
    .filter((group) => group.items.length > 0);
}

// Platform (super_admin) groups sit on a separate axis from org RBAC, so they
// are appended after filtering. Used by the sidebar, mobile nav and tests.
export function withPlatformGroups(
  groups: NavGroup[],
  user: { platform_role?: string | null } | null | undefined,
): NavGroup[] {
  return user?.platform_role === "super_admin" ? [...groups, ...PLATFORM_NAV_GROUPS] : groups;
}

export function useVisibleNavGroups(groups: NavGroup[] = MAIN_NAV_GROUPS): NavGroup[] {
  return filterNavGroups(groups, usePermissions(), useTerminology());
}

// Every nav destination the user can reach (sidebar + both hubs), first label
// per href wins. Used for breadcrumbs and page search so hub-only pages
// (Revision, Journal, Question Bank, ...) resolve like sidebar ones.
const ALL_GROUPS = () => [MAIN_NAV_GROUPS, LEARN_HUB_GROUPS, TEACHING_HUB_GROUPS].flat();

export function useAllVisibleNavItems(): NavItem[] {
  const visible = useVisibleNavGroups(ALL_GROUPS());
  const seen = new Set<string>();
  return visible.flatMap((g) => g.items).filter((i) => !seen.has(i.href) && seen.add(i.href));
}

// ─────────────────────────────────────────────
// LEARN HUB — every content-type destination (courses, assessments, practice,
// wiki, ...) lives behind one sidebar
// entry (ALL_NAV_ITEMS.learn_hub → /learn) instead of each having its own
// permanent slot. Rendered as cards on that page via useVisibleNavGroups
// (frontend/app/(app)/learn/page.tsx), so it's gated exactly like the sidebar.
// ─────────────────────────────────────────────

export const LEARN_HUB_GROUPS: NavGroup[] = [
  {
    label: "Learning",
    items: [
      ALL_NAV_ITEMS.courses,
      ALL_NAV_ITEMS.roadmap,
      ALL_NAV_ITEMS.interview_prep,
      ALL_NAV_ITEMS.labs,
      ALL_NAV_ITEMS.assessments,
    ],
  },
  {
    label: "Library",
    items: [
      ALL_NAV_ITEMS.review,
      ALL_NAV_ITEMS.mistakes,
      ALL_NAV_ITEMS.highlights,
      ALL_NAV_ITEMS.sheet_tracker,
      ALL_NAV_ITEMS.learning_journal,
      ALL_NAV_ITEMS.diary,
      ALL_NAV_ITEMS.captures,
      ALL_NAV_ITEMS.wiki,
      ALL_NAV_ITEMS.interview_exp,
      ALL_NAV_ITEMS.algo_visualizer,
      ALL_NAV_ITEMS.workspaces,
    ],
  },
  // "Tools" group (System Design, Interview Board, Load Test) removed: those
  // routes have no page.tsx yet, so the cards 404'd. Re-add once each ships.
];

// ─────────────────────────────────────────────
// TEACH HUB — course/lab/assessment authoring, question bank, mentoring and
// delivery for the /teach page, reached via the "Instructor" sidebar entry
// (ALL_NAV_ITEMS.teach_hub). Batches (cohort_groups) is also a direct sidebar
// link — a roster tool used constantly. Rendered as cards on /teach via
// useVisibleNavGroups (frontend/app/(app)/teach/page.tsx).
// ─────────────────────────────────────────────

export const TEACHING_HUB_GROUPS: NavGroup[] = [
  {
    label: "Courses",
    items: [
      ALL_NAV_ITEMS.manage_courses,
      ALL_NAV_ITEMS.course_analytics,
      ALL_NAV_ITEMS.lab_builder,
      ALL_NAV_ITEMS.lab_library,
      ALL_NAV_ITEMS.library,
    ],
  },
  {
    label: "Assessments",
    items: [
      ALL_NAV_ITEMS.instructor_assessments,
      ALL_NAV_ITEMS.question_bank,
    ],
  },
  {
    label: "Mentoring",
    items: [
      ALL_NAV_ITEMS.mentor_dashboard,
      ALL_NAV_ITEMS.mentor_tickets,
    ],
  },
  {
    label: "Delivery",
    items: [
      ALL_NAV_ITEMS.cohort_groups,
      ALL_NAV_ITEMS.cohorts,
    ],
  },
];

export const MAIN_NAV_GROUPS: NavGroup[] = [
  {
    items: [
      ALL_NAV_ITEMS.dashboard,
      ALL_NAV_ITEMS.calendar,
      ALL_NAV_ITEMS.support,
    ],
  },
  {
    label: "Learn",
    items: [
      ALL_NAV_ITEMS.learn_hub,
      ALL_NAV_ITEMS.mentors,
    ],
  },
  {
    label: "Teach",
    items: [
      ALL_NAV_ITEMS.teach_hub,
      ALL_NAV_ITEMS.cohort_groups,
    ],
  },
  {
    label: "Mentoring",
    items: [
      ALL_NAV_ITEMS.mentor_dashboard,
      ALL_NAV_ITEMS.mentor_tickets_nav,
    ],
  },
  {
    label: "Support",
    items: [ALL_NAV_ITEMS.support_queue],
  },
  {
    label: "Administration",
    items: [
      ALL_NAV_ITEMS.admin_rbac,
      ALL_NAV_ITEMS.admin_users,
      ALL_NAV_ITEMS.admin_coupons,
      ALL_NAV_ITEMS.admin_content_reports,
      ALL_NAV_ITEMS.org_settings,
    ],
  },
];
