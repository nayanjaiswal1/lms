import { Briefcase, Cpu, Sparkles, Layers, Bot, type LucideIcon } from "lucide-react";
import ROUTES from "@/lib/routes";

export interface PlatformNavItem {
  label: string;
  href:  string;
  icon:  LucideIcon;
  exact?: boolean;
}

export interface PlatformNavGroup {
  label: string;
  items: PlatformNavItem[];
}

// Static — every super_admin sees every item. Unlike the tenant sidebar
// (lib/nav.ts), there is no per-item RBAC/feature axis here: the whole
// /platform namespace is gated once at app/platform/layout.tsx. Grouped so
// related sub-views (e.g. the three Highlights lenses) nest under their own
// subsection heading instead of sitting flat alongside Jobs/Worker Health.
export const PLATFORM_NAV_GROUPS: PlatformNavGroup[] = [
  {
    label: "Platform",
    items: [
      { label: "Jobs",          href: ROUTES.PLATFORM_JOBS,         icon: Briefcase, exact: true },
      { label: "Worker Health", href: ROUTES.PLATFORM_JOBS_WORKERS, icon: Cpu },
    ],
  },
  {
    label: "Highlights",
    items: [
      { label: "Confusing Content", href: ROUTES.PLATFORM_HIGHLIGHTS,           icon: Sparkles, exact: true },
      { label: "By Source Type",    href: ROUTES.PLATFORM_HIGHLIGHTS_BY_SOURCE, icon: Layers },
      { label: "By Model",          href: ROUTES.PLATFORM_HIGHLIGHTS_BY_MODEL,  icon: Bot },
    ],
  },
];
