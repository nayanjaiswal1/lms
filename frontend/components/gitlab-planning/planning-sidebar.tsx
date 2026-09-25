"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChevronLeft } from "lucide-react";
import { PLANNING_SIDEBAR_NAV } from "@/components/gitlab-planning/planning-nav";
import ROUTES from "@/lib/routes";
import { cn } from "@/lib/utils";

interface PlanningSidebarProps {
  /** Server-rendered user block (streams in via Suspense). */
  user: React.ReactNode;
}

export function PlanningSidebar({ user }: PlanningSidebarProps) {
  const pathname = usePathname();

  return (
    <aside className="sticky top-0 z-sticky hidden h-dvh w-64 shrink-0 flex-col justify-between border-r border-(--ae-line)/80 bg-(--ae-card) lg:flex">
      <div className="p-5">
        <div className="mb-8">{user}</div>
        <nav aria-label="Planning navigation" className="space-y-1.5">
          {PLANNING_SIDEBAR_NAV.map(({ label, href, icon: Icon }) => {
            const active = pathname === href;
            return (
              <Link
                aria-current={active ? "page" : undefined}
                className={cn(
                  "flex items-center gap-3 rounded-xl px-3.5 py-2.5 text-sm transition-colors",
                  active
                    ? "bg-(--ae-brand-soft) font-semibold text-(--ae-brand)"
                    : "font-medium text-(--ae-dim) hover:bg-(--ae-hover) hover:text-(--ae-ink)",
                )}
                href={href}
                key={href}
              >
                <Icon aria-hidden className={cn("size-5", active ? "text-(--ae-brand)" : "text-(--ae-muted)")} />
                <span>{label}</span>
              </Link>
            );
          })}
        </nav>
      </div>
      <div className="border-t border-(--ae-soft) p-4">
        <Link
          className="flex w-full items-center gap-2 rounded-lg px-3 py-2 text-xs font-semibold text-(--ae-dim) transition-colors hover:bg-(--ae-hover) hover:text-(--ae-ink)"
          href={`${ROUTES.GITLAB_PLANNING}#quick-notes`}
        >
          <ChevronLeft aria-hidden className="size-4 text-(--ae-faint)" />
          <span>Quick Notes</span>
        </Link>
      </div>
    </aside>
  );
}
