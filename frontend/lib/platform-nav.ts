import { Briefcase, Cpu, ToggleLeft, type LucideIcon } from "lucide-react";
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
// /platform namespace is gated once at app/platform/layout.tsx.
//
// Highlights (ROUTES.PLATFORM_HIGHLIGHTS) has no row here — it's reached via
// the "Confusing Content" tab on the tenant /highlights page (super_admin
// only), merged with Saved Highlights into one sidebar entry instead of two.
export const PLATFORM_NAV_GROUPS: PlatformNavGroup[] = [
  {
    label: "Platform",
    items: [
      { label: "Jobs",          href: ROUTES.PLATFORM_JOBS,         icon: Briefcase, exact: true },
      { label: "Worker Health", href: ROUTES.PLATFORM_JOBS_WORKERS, icon: Cpu },
      { label: "Features",      href: ROUTES.PLATFORM_FEATURES,     icon: ToggleLeft },
    ],
  },
];
