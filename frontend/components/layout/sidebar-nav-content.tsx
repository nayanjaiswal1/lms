"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { AccessGate } from "@/components/shared/access-gate";
import { useVisibleNavGroups, type NavGroup } from "@/lib/nav";
import { PLATFORM_NAV_GROUPS } from "@/lib/platform-nav";
import { cn } from "@/lib/utils";
import type { AuthUser } from "@/lib/server/auth";

interface Props {
  /** Called after a nav link is clicked — used to close the mobile drawer. */
  onNavigate?: () => void;
  /** Icon-only rail mode — hides labels and group headings. */
  collapsed?: boolean;
  /** Adds the Platform / Highlights subsections when the user is a platform
   * super_admin — a separate axis from org-scoped RBAC, so it can't be
   * expressed through the permission-filtered MAIN_NAV_GROUPS. */
  user?: AuthUser | null;
}

// Renders the permission-filtered nav groups shared by the desktop sidebar
// and the mobile drawer, so the two surfaces never drift apart.
export function SidebarNavContent({ onNavigate, collapsed = false, user }: Props) {
  const groups = useVisibleNavGroups();
  const pathname = usePathname();

  const visibleGroups: NavGroup[] =
    user?.platform_role === "super_admin"
      ? [...groups, ...PLATFORM_NAV_GROUPS]
      : groups;

  return (
    <div className="flex flex-col gap-6 flex-1 min-h-0 overflow-y-auto px-3 py-6 mr-1">
      {visibleGroups.map((group, i) => (
        <div className="flex flex-col gap-1" key={group.label ?? `group-${i}`}>
          {group.label && !collapsed && (
            <p className="px-3 text-xs font-semibold text-muted-foreground uppercase tracking-widest mb-1">
              {group.label}
            </p>
          )}
          {group.items.map((item) => {
            const isActive = item.exact
              ? pathname === item.href
              : pathname.startsWith(item.href);

            const link = (
              <Link
                aria-current={isActive ? "page" : undefined}
                aria-label={collapsed ? item.label : undefined}
                className={cn(
                  "flex items-center gap-3 rounded-md px-3 py-2 text-sm transition-colors",
                  collapsed && "justify-center px-0",
                  item.feature && !collapsed && "flex-1 min-w-0",
                  isActive
                    ? "bg-accent text-accent-foreground font-medium"
                    : "text-sidebar-foreground hover:bg-accent/60 hover:text-accent-foreground",
                )}
                href={item.href}
                key={item.href}
                title={collapsed ? item.label : undefined}
                onClick={onNavigate}
              >
                <item.icon aria-hidden className="h-4 w-4 shrink-0 scale-90" />
                {!collapsed && item.label}
              </Link>
            );

            if (!item.feature) return link;

            return (
              <AccessGate collapsed={collapsed} feature={item.feature} key={item.href} mode={item.mode ?? "badge"}>
                {link}
              </AccessGate>
            );
          })}
        </div>
      ))}
    </div>
  );
}
