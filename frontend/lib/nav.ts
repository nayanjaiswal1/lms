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
  type LucideIcon,
} from "lucide-react";
import ROUTES from "@/lib/routes";
import { FEATURES, type Feature } from "@/lib/features";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { usePermissions } from "@/lib/auth/permissions";
import { useTerminology } from "@/lib/terminology-context";
import { type Terminology } from "@/lib/terminology";

// ─────────────────────────────────────────────
// Nav item shape
// `feature`          — if present, item is wrapped in <AccessGate> automatically.
// `requiredPermission` — RBAC permission code(s); item hidden unless the user
//                       holds it. An array is an any-of check (e.g. a hub
//                       entry that should show if the user can reach any one
//                       of the pages it links to).
// `hideForPermission`  — inverse of the above; item hidden if user DOES hold it
//                       (e.g. hide the learner-facing mentor directory from
//                       admins, who already have the full Users page for that).
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
  hideForPermission?:  string;
  mode?:               "badge" | "hide";
  exact?:              boolean;
  hideFromBottomNav?:  boolean;
}

export interface NavGroup {
  label?: string;
  items:  NavItem[];
}

// ─────────────────────────────────────────────
// TOP NAVBAR (public + auth-aware)
// ─────────────────────────────────────────────


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
    label: "Debug Labs",
    href:  ROUTES.LABS_CATALOG,
    icon:  Bug,
  },
  roadmap: {
    label: "Roadmap",
    href:  ROUTES.ROADMAP,
    icon:  Map,
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
    hideForPermission:  PERMISSIONS.ADMIN.VIEW_MEMBERS,
  },

  support: {
    label:  "Help & Support",
    href:   ROUTES.SUPPORT,
    icon:   LifeBuoy,
    hideFromBottomNav: true,
  },
  learn_hub: {
    label: "Learn",
    href:  ROUTES.LEARN,
    icon:  BookOpen,
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
  mistakes: {
    label:              "My Mistakes",
    href:               ROUTES.MISTAKES,
    icon:               Brain,
    requiredPermission: PERMISSIONS.PRACTICE.USE,
  },
  algo_visualizer: {
    label: "Algorithm Visualizer",
    href:  ROUTES.ALGO_VISUALIZER,
    icon:  Binary,
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
  projects: {
    label:               "Projects",
    href:                ROUTES.PROJECTS,
    icon:                FolderGit2,
    feature:             FEATURES.GITLAB_INTEGRATION,
    requiredPermission:  PERMISSIONS.PROJECTS.VIEW,
    mode:                "hide",
  },
  // Not gated on projects.create: creating a workspace needs that permission,
  // but any org member can be *invited into* someone else's workspace as a
  // member/viewer, so the nav entry itself has to stay visible to everyone —
  // the create button on /workspaces is what's gated instead.
  workspaces: {
    label: "Workspaces",
    href:  ROUTES.WORKSPACES,
    icon:  Briefcase,
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
    label:               "Existing Labs",
    href:                ROUTES.LABS_CATALOG,
    icon:                Bug,
    requiredPermission:  PERMISSIONS.LABAUTHOR.COMPOSE,
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

// Shared by the sidebar (MAIN_NAV_GROUPS) and the Learn hub page
// (LEARN_HUB_GROUPS) so permission filtering, the admin mentor-directory
// exclusion, and batch terminology only need to be correct in one place.
export function useVisibleNavGroups(groups: NavGroup[] = MAIN_NAV_GROUPS): NavGroup[] {
  const perms = usePermissions();
  const t = useTerminology();

  return groups
    .map((group) => ({
      ...group,
      items: group.items
        .filter((item) => {
          if (!item.requiredPermission) return true;
          return Array.isArray(item.requiredPermission)
            ? item.requiredPermission.some((p) => perms.has(p))
            : perms.has(item.requiredPermission);
        })
        .filter((item) => !item.hideForPermission || !perms.has(item.hideForPermission))
        .map((item) =>
          BATCH_LABEL_HREFS.has(item.href) ? { ...item, label: applyTerminology(item.label, t) } : item,
        ),
    }))
    .filter((group) => group.items.length > 0);
}

// ─────────────────────────────────────────────
// LEARN HUB — every content-type destination (courses, assessments, practice,
// wiki, the design/interview/load-test tools, ...) lives behind one sidebar
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
      ALL_NAV_ITEMS.projects,
    ],
  },
  {
    label: "Library",
    items: [
      ALL_NAV_ITEMS.highlights,
      ALL_NAV_ITEMS.sheet_tracker,
      ALL_NAV_ITEMS.captures,
      ALL_NAV_ITEMS.wiki,
      ALL_NAV_ITEMS.interview_exp,
      ALL_NAV_ITEMS.algo_visualizer,
    ],
  },
  // Instructor tools. Each item keeps its own requiredPermission, so learners never see
  // this group (useVisibleNavGroups drops it when empty). Labels are
  // overridden where they'd collide with the learner-side cards above.
  {
    label: "Teaching",
    items: [
      { ...ALL_NAV_ITEMS.manage_courses,         label: "Create Course" },
      ALL_NAV_ITEMS.lab_builder,
      ALL_NAV_ITEMS.lab_library,
      { ...ALL_NAV_ITEMS.instructor_assessments, label: "Manage Assessments" },
      ALL_NAV_ITEMS.question_bank,
      { ...ALL_NAV_ITEMS.mentor_dashboard,       label: "Mentoring" },
      ALL_NAV_ITEMS.mentor_tickets,
    ],
  },
  // "Tools" group (System Design, Interview Board, Load Test) removed: those
  // routes have no page.tsx yet, so the cards 404'd. Re-add once each ships.
];

// ─────────────────────────────────────────────
// TEACH HUB — course authoring, assessment authoring, question bank, and
// mentoring for the /teach page (reached via breadcrumbs). The same items also
// appear in the Learn hub's "Teaching" group; there's no separate sidebar
// entry. Batches (cohort_groups) stays a direct
// sidebar link — it's a delivery/roster tool used constantly, not a
// destination someone browses to occasionally like the hub cards. Rendered
// as cards on /teach via useVisibleNavGroups (frontend/app/(app)/teach/page.tsx).
// ─────────────────────────────────────────────

export const TEACHING_HUB_GROUPS: NavGroup[] = [
  {
    label: "Courses",
    items: [
      ALL_NAV_ITEMS.manage_courses,
      ALL_NAV_ITEMS.course_analytics,
      ALL_NAV_ITEMS.lab_builder,
      ALL_NAV_ITEMS.lab_library,
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
];

export const MAIN_NAV_GROUPS: NavGroup[] = [
  {
    // No label: this group already contains a "Learn" link (learn_hub)
    // alongside Dashboard/Mentors/Calendar, which aren't Learn sub-items —
    // a "Learn" header over that mix duplicated the child item and misnamed
    // the rest.
    items: [
      ALL_NAV_ITEMS.dashboard,
      ALL_NAV_ITEMS.learn_hub,
      ALL_NAV_ITEMS.workspaces,
      ALL_NAV_ITEMS.mentors,
      ALL_NAV_ITEMS.support,
      ALL_NAV_ITEMS.calendar,
    ],
  },
  {
    // No label: instructor tools now live in the Learn hub's "Teaching"
    // group; Batches stays a direct link since it's used constantly.
    items: [
      ALL_NAV_ITEMS.cohort_groups,
    ],
  },
  {
    label: "Administration",
    items: [
      ALL_NAV_ITEMS.admin_rbac,
      ALL_NAV_ITEMS.admin_users,
      ALL_NAV_ITEMS.admin_coupons,
      ALL_NAV_ITEMS.org_settings,
    ],
  },
];
