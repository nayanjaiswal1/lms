"use client";

import { usePathname } from "next/navigation";
import { BrandMark } from "@/components/shared/brand-mark";
import { SidebarNavContent } from "@/components/layout/sidebar-nav-content";
import { SidebarUserMenu } from "@/components/layout/sidebar-user-menu";
import { isCourseLearnRoute } from "@/lib/routes";
import type { AuthUser } from "@/lib/server/auth";

interface Props {
  user: AuthUser | null;
}

export function Sidebar({ user }: Props) {
  const pathname = usePathname();
  if (isCourseLearnRoute(pathname)) return null;

  return (
    <aside aria-label="Main navigation" className="app-sidebar">
      <div className="px-5 py-5 border-b border-sidebar-border">
        <BrandMark />
      </div>
      <SidebarNavContent />
      {user && <SidebarUserMenu user={user} />}
    </aside>
  );
}
