import { ArrowRight, History, Pencil, Plus } from "lucide-react";
import type { AeChangeLogEntry, AeTone } from "@/lib/server/gitlab-planning";

const KIND: Record<AeChangeLogEntry["kind"], { label: string; tone: AeTone; icon: typeof Plus }> = {
  added: { label: "Added", tone: "emerald", icon: Plus },
  moved: { label: "Moved", tone: "blue", icon: ArrowRight },
  updated: { label: "Updated", tone: "amber", icon: Pencil },
};

interface ChangeLogCardProps {
  entries: AeChangeLogEntry[];
}

export function ChangeLogCard({ entries }: ChangeLogCardProps) {
  return (
    <section aria-label="Change log" className="card-base p-4 shadow-card">
      <div className="mb-3 flex-between">
        <div className="flex items-center gap-2">
          <History aria-hidden className="size-4 text-muted-foreground" />
          <h3 className="text-xs font-bold text-foreground">Change Log</h3>
        </div>
        <a className="text-xs font-semibold text-primary hover:underline" href="#change-log">View all</a>
      </div>
      <ul className="space-y-2.5 text-xs" id="change-log">
        {entries.map((e) => {
          const kind = KIND[e.kind];
          const Icon = kind.icon;
          return (
            <li className="flex-between gap-2" key={e.id}>
              <div className="flex min-w-0 items-center gap-2">
                <span className="whitespace-nowrap text-muted-foreground">{e.time}</span>
                <span className="inline-flex shrink-0 items-center gap-0.5 rounded border border-border bg-(--t-50) px-1.5 py-0.5 text-xs font-semibold text-(--t-700)" data-tone={kind.tone}>
                  <Icon aria-hidden className="size-2.5" /> {kind.label}
                </span>
                <span className="min-w-0 truncate font-medium text-foreground">{e.message}</span>
              </div>
              <span className="shrink-0 font-medium text-muted-foreground">{e.actor}</span>
            </li>
          );
        })}
      </ul>
    </section>
  );
}
