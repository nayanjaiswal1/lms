import { FolderKanban, LayoutDashboard, ListChecks, Settings, Sparkles, SquareCheckBig, House, type LucideIcon } from "lucide-react";
import ROUTES from "@/lib/routes";

export interface PlanningNavItem {
  label: string;
  href: string;
  icon: LucideIcon;
}

// Sidebar (lg+) — the Stitch rail, pointed at the pages that exist.
export const PLANNING_SIDEBAR_NAV: PlanningNavItem[] = [
  { label: "Dashboard", href: ROUTES.GITLAB_PLANNING, icon: LayoutDashboard },
  { label: "Board", href: ROUTES.PROJECTS_BOARD, icon: FolderKanban },
  { label: "Issues / List", href: ROUTES.GITLAB_ISSUES, icon: ListChecks },
  { label: "Settings", href: ROUTES.SETTINGS_INTEGRATIONS, icon: Settings },
];

// Bottom nav (<lg) — Stitch mobile layout.
export const PLANNING_BOTTOM_NAV: PlanningNavItem[] = [
  { label: "Home", href: ROUTES.PROJECTS, icon: House },
  { label: "Matrix", href: ROUTES.GITLAB_PLANNING, icon: LayoutDashboard },
  { label: "Tasks", href: ROUTES.GITLAB_ISSUES, icon: SquareCheckBig },
  { label: "AI", href: `${ROUTES.GITLAB_PLANNING}#ai-assistant`, icon: Sparkles },
  { label: "Menu", href: ROUTES.SETTINGS_INTEGRATIONS, icon: Settings },
];
