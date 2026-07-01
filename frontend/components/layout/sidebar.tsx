"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { AccessGate } from "@/components/shared/access-gate";
import { BrandMark } from "@/components/shared/brand-mark";
import { usePermissions } from "@/lib/auth/permissions";
import { SidebarUserMenu } from "@/components/layout/sidebar-user-menu";
import { cn } from "@/lib/utils";
import { MAIN_NAV_GROUPS } from "@/lib/nav";
import type { AuthUser } from "@/lib/server/auth";

interface Props {
  user: AuthUser | null;
}

export function Sidebar({ user }: Props) {
  const nav = MAIN_NAV_GROUPS;
  const pathname = usePathname();
  const perms = usePermissions();

  const visibleGroups = nav
    .map((group) => ({
      ...group,
      items: group.items.filter(
        (item) => !item.requiredPermission || perms.has(item.requiredPermission),
      ),
    }))
    .filter((group) => group.items.length > 0);

  return (
    <aside aria-label="Main navigation" className="app-sidebar">
      <div className="px-5 py-5 border-b border-sidebar-border">
        <BrandMark />
      </div>
      <div className="flex flex-col gap-6 flex-1 min-h-0 overflow-y-auto px-3 py-6">
        {visibleGroups.map((group, i) => (
          <div className="flex flex-col gap-1" key={group.label ?? `group-${i}`}>
            {group.label && (
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
                  className={cn(
                    "flex items-center gap-3 rounded-md px-3 py-2 text-sm transition-colors",
                    isActive
                      ? "bg-accent text-accent-foreground font-medium"
                      : "text-sidebar-foreground hover:bg-accent/60 hover:text-accent-foreground",
                  )}
                  href={item.href}
                  key={item.href}
                >
                  <item.icon aria-hidden className="h-4 w-4 shrink-0" />
                  {item.label}
                </Link>
              );

              if (!item.feature) return link;

              return (
                <AccessGate feature={item.feature} key={item.href} mode={item.mode ?? "badge"}>
                  {link}
                </AccessGate>
              );
            })}
          </div>
        ))}
      </div>

      {user && <SidebarUserMenu user={user} />}
    </aside>
  );
}
