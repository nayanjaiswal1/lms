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
    <section aria-label="Change log" className="rounded-2xl border border-(--ae-line)/80 bg-(--ae-card) p-4 shadow-sm">
      <div className="mb-3 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <History aria-hidden className="size-4 text-(--ae-muted)" />
          <h3 className="text-xs font-bold text-(--ae-ink)">Change Log</h3>
        </div>
        <a className="text-[11px] font-semibold text-(--ae-brand) hover:underline" href="#change-log">View all</a>
      </div>
      <ul className="space-y-2.5 text-[11px]" id="change-log">
        {entries.map((e) => {
          const kind = KIND[e.kind];
          const Icon = kind.icon;
          return (
            <li className="flex items-center justify-between gap-2" key={e.id}>
              <div className="flex min-w-0 items-center gap-2">
                <span className="whitespace-nowrap text-(--ae-faint)">{e.time}</span>
                <span className="inline-flex shrink-0 items-center gap-0.5 rounded border border-(--t-200) bg-(--t-50) px-1.5 py-0.5 text-[10px] font-semibold text-(--t-700)" data-tone={kind.tone}>
                  <Icon aria-hidden className="size-2.5" /> {kind.label}
                </span>
                <span className="min-w-0 truncate font-medium text-(--ae-body)">{e.message}</span>
              </div>
              <span className="shrink-0 font-medium text-(--ae-muted)">{e.actor}</span>
            </li>
          );
        })}
      </ul>
    </section>
  );
}
