"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { PLANNING_BOTTOM_NAV } from "@/components/gitlab-planning/planning-nav";
import { cn } from "@/lib/utils";

export function PlanningBottomNav() {
  const pathname = usePathname();

  return (
    <nav
      aria-label="Mobile navigation"
      className="safe-bottom fixed inset-x-0 bottom-0 z-sticky flex items-center justify-around border-t border-(--ae-line)/80 bg-(--ae-card)/95 px-2 py-1.5 shadow-lg backdrop-blur-md lg:hidden"
    >
      {PLANNING_BOTTOM_NAV.map(({ label, href, icon: Icon }) => {
        const active = pathname === href;
        return (
          <Link
            key={label}
            href={href}
            aria-current={active ? "page" : undefined}
            className={cn(
              "touch-target flex min-w-14 flex-col items-center justify-center py-1 transition-colors",
              active ? "text-(--ae-brand)" : "text-(--ae-muted) hover:text-(--ae-ink)",
            )}
          >
            <span className="relative">
              <Icon className="size-5" aria-hidden />
              {active && <span className="absolute -right-1 -top-1 size-2 rounded-full bg-(--ae-brand-500)" />}
            </span>
            <span className={cn("mt-0.5 text-[10px]", active ? "font-bold" : "font-medium")}>{label}</span>
          </Link>
        );
      })}
    </nav>
  );
}
