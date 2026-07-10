"use client";

import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { BrandMark } from "@/components/shared/brand-mark";
import { SidebarNavContent } from "@/components/layout/sidebar-nav-content";
import { SidebarUserMenu } from "@/components/layout/sidebar-user-menu";
import { isCourseLearnRoute } from "@/lib/routes";
import { cn } from "@/lib/utils";
import type { AuthUser } from "@/lib/server/auth";

interface Props {
  user: AuthUser | null;
}

const STORAGE_KEY = "mf-sidebar-collapsed";

export function Sidebar({ user }: Props) {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);

  // Sidebar collapse is a persisted layout preference, not page state — it
  // must be read from localStorage after mount so SSR and first client
  // render match (no hydration mismatch), then take over for the session.
  useEffect(() => {
    setCollapsed(localStorage.getItem(STORAGE_KEY) === "true");
  }, []);

  if (isCourseLearnRoute(pathname)) return null;

  function toggleCollapsed() {
    setCollapsed((prev) => {
      const next = !prev;
      localStorage.setItem(STORAGE_KEY, String(next));
      return next;
    });
  }

  return (
    <div className="hidden lg:block group relative shrink-0">
      <aside
        aria-label="Main navigation"
        className={cn("app-sidebar transition-[width] duration-normal ease-smooth", collapsed && "w-18")}
      >
        <div className={cn("px-5 py-5 border-b border-sidebar-border overflow-hidden", collapsed && "px-3")}>
          <BrandMark showName={!collapsed} />
        </div>

        <SidebarNavContent collapsed={collapsed} user={user} />
        {user && <SidebarUserMenu collapsed={collapsed} user={user} />}
      </aside>

      {/* Edge-mounted toggle — straddles the sidebar/content border, à la Linear/Notion/VS Code */}
      <button
        aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
        className={cn(
          "absolute top-9 -right-3 z-raised flex-center h-6 w-6 rounded-full",
          "border border-border bg-background text-muted-foreground shadow-card",
          "opacity-0 group-hover:opacity-100 hover:!opacity-100 hover:text-foreground hover:border-primary/50",
          "transition-all duration-fast"
        )}
        type="button"
        onClick={toggleCollapsed}
      >
        {collapsed ? (
          <ChevronRight aria-hidden="true" size={14} />
        ) : (
          <ChevronLeft aria-hidden="true" size={14} />
        )}
      </button>
    </div>
  );
}
