"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Menu, X } from "lucide-react";
import { BrandMark } from "@/components/shared/brand-mark";
import { SidebarUserMenu } from "@/components/layout/sidebar-user-menu";
import { PLATFORM_NAV_GROUPS } from "@/lib/platform-nav";
import { cn } from "@/lib/utils";
import ROUTES from "@/lib/routes";
import type { AuthUser } from "@/lib/server/auth";

interface Props {
  user: AuthUser;
}

export function PlatformMobileNav({ user }: Props) {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();

  return (
    <>
      <header className="app-header lg:hidden">
        <button
          aria-label="Open menu"
          className="touch-target -ml-2 flex items-center justify-center rounded-md hover:bg-accent/60 transition-colors duration-fast"
          onClick={() => setOpen(true)}
        >
          <Menu aria-hidden className="h-5 w-5" />
        </button>
        <Link aria-label="Go to your home page" href={user.default_landing_page || ROUTES.DASHBOARD}>
          <BrandMark />
        </Link>
      </header>

      {open && (
        <button
          aria-label="Close navigation"
          className="sidebar-drawer-backdrop"
          type="button"
          onClick={() => setOpen(false)}
        />
      )}

      <aside
        aria-hidden={!open}
        aria-label="Platform navigation"
        className={cn("sidebar-drawer transition-transform", open ? "translate-x-0" : "-translate-x-full")}
        inert={!open}
      >
        <div className="flex items-center justify-between px-5 py-5 border-b border-sidebar-border">
          <Link
            aria-label="Go to your home page"
            href={user.default_landing_page || ROUTES.DASHBOARD}
            onClick={() => setOpen(false)}
          >
            <BrandMark />
          </Link>
          <button
            aria-label="Close menu"
            className="touch-target flex items-center justify-center rounded-md hover:bg-accent/60 transition-colors duration-fast"
            onClick={() => setOpen(false)}
          >
            <X aria-hidden className="h-5 w-5" />
          </button>
        </div>

        <nav className="flex flex-col gap-6 px-3 py-6">
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
                    onClick={() => setOpen(false)}
                  >
                    <item.icon aria-hidden className="h-4 w-4 shrink-0" />
                    {item.label}
                  </Link>
                );
              })}
            </div>
          ))}
        </nav>

        <SidebarUserMenu user={user} onNavigate={() => setOpen(false)} />
      </aside>
    </>
  );
}
