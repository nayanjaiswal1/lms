"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { AccessGate } from "@/components/shared/access-gate";
import { useVisibleNavGroups } from "@/lib/nav";
import { cn } from "@/lib/utils";

interface Props {
  /** Called after a nav link is clicked — used to close the mobile drawer. */
  onNavigate?: () => void;
}

// Renders the permission-filtered nav groups shared by the desktop sidebar
// and the mobile drawer, so the two surfaces never drift apart.
export function SidebarNavContent({ onNavigate }: Props) {
  const visibleGroups = useVisibleNavGroups();
  const pathname = usePathname();

  return (
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
                onClick={onNavigate}
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
  );
}
