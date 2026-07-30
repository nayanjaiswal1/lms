"use client";

import Link from "next/link";
import { AccessGate } from "@/components/shared/access-gate";
import { LEARN_HUB_GROUPS, TEACHING_HUB_GROUPS, useVisibleNavGroups } from "@/lib/nav";

// NavGroup items carry LucideIcon components, which are functions and can't
// cross the server→client props boundary. The catalogue is looked up by a
// plain string key instead of being passed in as a prop from a Server
// Component page.
const CATALOGUES = {
  learn: LEARN_HUB_GROUPS,
  teach: TEACHING_HUB_GROUPS,
} as const;

interface NavHubGridProps {
  catalogue: keyof typeof CATALOGUES;
  // Short status line per card (e.g. "4 enrolled", "12 due"), keyed by the
  // nav item's href. A tile with no entry (or an empty string) just renders
  // without one.
  stats?: Record<string, string>;
}

// Renders a catalogue of content-type destinations as a dial-pad of round
// keys, grouped by section, instead of a card grid, list, or table. Shared by
// the Learn hub (/learn) and Teach hub (/teach) so both surfaces stay visually
// and behaviorally identical.
export function NavHubGrid({ catalogue, stats = {} }: NavHubGridProps) {
  const groups = useVisibleNavGroups(CATALOGUES[catalogue]);

  if (groups.length === 0) {
    return (
      <div className="empty-state">
        <p className="text-muted-foreground">Nothing here yet for your role.</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-8">
      {groups.map((group) => (
        <section key={group.label}>
          <div className="mb-4 inline-flex flex-col gap-1.5">
            <span className="text-xs font-semibold uppercase tracking-widest text-muted-foreground">{group.label}</span>
            <span aria-hidden className="h-0.5 w-6 rounded-full bg-primary" />
          </div>
          <div className="grid grid-cols-3 gap-x-2 gap-y-6 sm:grid-cols-4 lg:grid-cols-6">
            {group.items.map((item) => {
              const stat = stats[item.href];
              const dial = (
                <Link
                  className="group flex flex-col items-center gap-2 rounded-xl p-2 text-center focus-visible:outline-none"
                  href={item.href}
                >
                  <span className="flex h-16 w-16 shrink-0 items-center justify-center rounded-full border border-border bg-card shadow-card transition-all duration-fast group-hover:-translate-y-0.5 group-hover:border-primary group-hover:bg-primary group-hover:shadow-raised group-focus-visible:-translate-y-0.5 group-focus-visible:border-primary group-focus-visible:bg-primary group-focus-visible:shadow-raised group-focus-visible:ring-2 group-focus-visible:ring-ring group-focus-visible:ring-offset-2 group-focus-visible:ring-offset-background">
                    <item.icon aria-hidden className="h-6 w-6 text-foreground transition-colors duration-fast group-hover:text-primary-foreground group-focus-visible:text-primary-foreground" />
                  </span>
                  <div className="min-w-0">
                    <p className="line-clamp-2 max-w-24 text-xs font-medium leading-tight text-foreground">{item.label}</p>
                    {stat && <p className="mt-0.5 max-w-24 truncate text-[11px] leading-tight text-muted-foreground">{stat}</p>}
                  </div>
                </Link>
              );

              if (!item.feature) return <div key={item.href}>{dial}</div>;

              return (
                <AccessGate feature={item.feature} key={item.href} mode={item.mode ?? "badge"}>
                  {dial}
                </AccessGate>
              );
            })}
          </div>
        </section>
      ))}
    </div>
  );
}
