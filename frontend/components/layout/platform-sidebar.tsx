"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { BrandMark } from "@/components/shared/brand-mark";
import { SidebarUserMenu } from "@/components/layout/sidebar-user-menu";
import { PLATFORM_NAV_GROUPS } from "@/lib/platform-nav";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";
import type { AuthUser } from "@/lib/server/auth";

interface Props {
  user: AuthUser;
}

export function PlatformSidebar({ user }: Props) {
  const pathname = usePathname();

  return (
    <aside aria-label="Platform navigation" className="app-sidebar">
      <div className="px-5 py-5 border-b border-sidebar-border">
        <Link aria-label="Go to your home page" href={user.default_landing_page || ROUTES.DASHBOARD}>
          <BrandMark />
        </Link>
        <p className="mt-1 text-xs font-semibold uppercase tracking-widest text-muted-foreground">
          Platform Console
        </p>
      </div>

      <nav className="flex flex-col gap-6 flex-1 min-h-0 overflow-y-auto px-3 py-6">
        {PLATFORM_NAV_GROUPS.map((group) => (
          <div className="flex flex-col gap-1" key={group.label}>
            <p className="px-3 text-xs font-semibold text-muted-foreground uppercase tracking-widest mb-1">
              {group.label}
            </p>
            {group.items.map((item) => {
              const isActive = item.exact ? pathname === item.href : pathname.startsWith(item.href);
              return (
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
            })}
          </div>
        ))}
      </nav>

      <SidebarUserMenu user={user} />
    </aside>
  );
}
