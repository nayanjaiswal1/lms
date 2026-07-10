"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Menu, X } from "lucide-react";
import { BrandMark } from "@/components/shared/brand-mark";
import { SidebarNavContent } from "@/components/layout/sidebar-nav-content";
import { SidebarUserMenu } from "@/components/layout/sidebar-user-menu";
import { useVisibleNavGroups } from "@/lib/nav";
import { useFeatureFlags } from "@/lib/feature-context";
import { cn } from "@/lib/utils";
import type { AuthUser } from "@/lib/server/auth";
import type { Feature } from "@/lib/features";

interface Props {
  user: AuthUser | null;
}

const BOTTOM_NAV_MAX_ITEMS = 4;

export function MobileNav({ user }: Props) {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();
  const visibleGroups = useVisibleNavGroups();
  const { orgFeatures, entitlements } = useFeatureFlags();

  // Bottom-nav slots are scarce (4 max) — only offer items that render as a
  // real, usable shortcut. A feature-gated item the org hasn't enabled (or
  // the user isn't entitled to) would otherwise occupy a slot and render
  // nothing, since AccessGate hides/locks it.
  const isReady = (feature?: Feature) =>
    !feature || (orgFeatures.has(feature) && entitlements.has(feature));

  const bottomNavItems = visibleGroups
    .flatMap((g) => g.items)
    .filter((item) => isReady(item.feature))
    .slice(0, BOTTOM_NAV_MAX_ITEMS);

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
        <BrandMark />
      </header>

      {open && (
        <button
          type="button"
          className="sidebar-drawer-backdrop"
          onClick={() => setOpen(false)}
          aria-label="Close navigation"
        />
      )}

      <aside
        aria-hidden={!open}
        aria-label="Main navigation"
        className={cn(
          "sidebar-drawer transition-transform",
          open ? "translate-x-0" : "-translate-x-full",
        )}
        inert={!open}
      >
        <div className="flex items-center justify-between px-5 py-5 border-b border-sidebar-border">
          <BrandMark />
          <button
            aria-label="Close menu"
            className="touch-target flex items-center justify-center rounded-md hover:bg-accent/60 transition-colors duration-fast"
            onClick={() => setOpen(false)}
          >
            <X aria-hidden className="h-5 w-5" />
          </button>
        </div>
        <SidebarNavContent user={user} onNavigate={() => setOpen(false)} />
        {user && <SidebarUserMenu user={user} onNavigate={() => setOpen(false)} />}
      </aside>

      <nav aria-label="Primary" className="bottom-nav">
        {bottomNavItems.map((item) => {
          const isActive = item.exact ? pathname === item.href : pathname.startsWith(item.href);

          return (
            <Link
              aria-current={isActive ? "page" : undefined}
              className="bottom-nav-item"
              href={item.href}
              key={item.href}
            >
              <item.icon aria-hidden className="h-5 w-5" />
              <span className="bottom-nav-item-label">{item.label}</span>
            </Link>
          );
        })}
        <button
          aria-label="Open menu"
          className="bottom-nav-item"
          onClick={() => setOpen(true)}
        >
          <Menu aria-hidden className="h-5 w-5" />
          <span className="bottom-nav-item-label">Menu</span>
        </button>
      </nav>
    </>
  );
}
