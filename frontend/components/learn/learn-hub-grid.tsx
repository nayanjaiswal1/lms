"use client";

import Link from "next/link";
import { AccessGate } from "@/components/shared/access-gate";
import { LEARN_HUB_GROUPS, useVisibleNavGroups } from "@/lib/nav";

// Renders every content-type destination (courses, assessments, practice,
// wiki, the design/interview/load-test tools, ...) as one card grid instead
// of each having its own permanent sidebar slot. Reuses useVisibleNavGroups
// so permission filtering and gating are identical to the sidebar's.
export function LearnHubGrid() {
  const groups = useVisibleNavGroups(LEARN_HUB_GROUPS);

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
          <h2 className="section-title mb-4">{group.label}</h2>
          <div className="card-grid">
            {group.items.map((item) => {
              const card = (
                <Link className="card-base card-interactive flex items-center gap-3 p-5" href={item.href} key={item.href}>
                  <item.icon aria-hidden className="h-5 w-5 shrink-0 text-primary" />
                  <span className="font-medium text-foreground">{item.label}</span>
                </Link>
              );

              if (!item.feature) return card;

              return (
                <AccessGate feature={item.feature} key={item.href} mode={item.mode ?? "badge"}>
                  {card}
                </AccessGate>
              );
            })}
          </div>
        </section>
      ))}
    </div>
  );
}
