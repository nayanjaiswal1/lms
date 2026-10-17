import {
  LayoutDashboard, Globe, Shield, ScrollText, Cpu, GitBranch, FlaskConical, Gauge, Flame,
  type LucideIcon,
} from "lucide-react";
import ROUTES from "@/lib/routes";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import { isPermitted } from "@/lib/auth/permission-filter";

export interface OrgSettingsNavItem {
  label: string;
  href: string;
  icon: LucideIcon;
  /** Mirrors the page's own server guard — keep in sync with that page. */
  requiredPermission: string;
  exact?: boolean;
}

const { MANAGE_ORG, VIEW_AUDIT_LOG } = PERMISSIONS.ADMIN;

export const ORG_SETTINGS_NAV: OrgSettingsNavItem[] = [
  { label: "Overview",       href: ROUTES.ORG_SETTINGS,              icon: LayoutDashboard, requiredPermission: MANAGE_ORG, exact: true },
  { label: "Domains",        href: ROUTES.ORG_SETTINGS_DOMAINS,      icon: Globe,           requiredPermission: MANAGE_ORG },
  { label: "Authentication", href: ROUTES.ORG_SETTINGS_AUTH,         icon: Shield,          requiredPermission: MANAGE_ORG },
  { label: "Integrations",   href: ROUTES.ORG_SETTINGS_INTEGRATIONS, icon: GitBranch,       requiredPermission: MANAGE_ORG },
  { label: "Labs",           href: ROUTES.ORG_SETTINGS_LABS,         icon: FlaskConical,    requiredPermission: MANAGE_ORG },
  { label: "Lab usage",      href: ROUTES.ADMIN_LABS_USAGE,          icon: Gauge,           requiredPermission: MANAGE_ORG },
  { label: "Warm pools",     href: ROUTES.ADMIN_LABS_WARM_POOLS,     icon: Flame,           requiredPermission: MANAGE_ORG },
  { label: "Audit Log",      href: ROUTES.ORG_SETTINGS_AUDIT,        icon: ScrollText,      requiredPermission: VIEW_AUDIT_LOG },
  { label: "Jobs",           href: ROUTES.ORG_SETTINGS_JOBS,         icon: Cpu,             requiredPermission: MANAGE_ORG },
];

// Any-of set the layout guard uses: holding none means no entry is visible.
export const ORG_SETTINGS_ACCESS: readonly string[] = [
  ...new Set(ORG_SETTINGS_NAV.map((i) => i.requiredPermission)),
];

export const visibleOrgSettingsNav = (perms: ReadonlySet<string>): OrgSettingsNavItem[] =>
  ORG_SETTINGS_NAV.filter((i) => isPermitted(i, perms));
