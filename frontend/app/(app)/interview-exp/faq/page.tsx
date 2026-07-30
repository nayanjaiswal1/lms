import type { Metadata } from "next";
import { HelpCircle } from "lucide-react";

import { listFaq, type FaqItem, type FaqStatus } from "@/lib/server/interview-exp";
import { FaqFilters } from "@/components/interview-exp/faq-filters";
import { FaqRow } from "@/components/interview-exp/faq-row";

export const metadata: Metadata = { title: "Frequently Asked Questions" };

interface FaqPageProps {
  searchParams: Promise<{ company?: string; tag?: string; status?: string }>;
}

const UNCATEGORIZED = "Uncategorized";

function groupByTag(items: FaqItem[]): Map<string, FaqItem[]> {
  const groups = new Map<string, FaqItem[]>();
  for (const item of items) {
    const key = item.tags[0] ?? UNCATEGORIZED;
    const group = groups.get(key);
    if (group) {
      group.push(item);
    } else {
      groups.set(key, [item]);
    }
  }
  return groups;
}

function ProgressBar({ done, total }: { done: number; total: number }) {
  const pct = total === 0 ? 0 : Math.round((done / total) * 100);
  return (
    <div className="flex items-center gap-3">
      <div className="progress-track w-full max-w-xs">
        {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width needs inline style */}
        <div className="progress-fill progress-fill-success" style={{ "--progress": `${pct}%` } as React.CSSProperties} />
      </div>
      <span className="shrink-0 text-xs font-medium tabular-nums text-muted-foreground">
        {done}/{total} done
      </span>
    </div>
  );
}

export default async function FaqPage({ searchParams }: FaqPageProps) {
  const { company, tag, status } = await searchParams;
  const items = await listFaq({
    company,
    tag,
    status: status && status !== "all" ? (status as FaqStatus) : undefined,
  });

  const totalDone = items.filter((i) => i.status === "done").length;
  const groups = groupByTag(items);

  return (
    <main className="page-container-sm">
      <div className="page-header">
        <div>
          <h1 className="page-title">Frequently Asked Questions</h1>
          <p className="text-sm text-muted-foreground">
            Every question asked across every interview experience, ranked by upvotes. Track your own progress
            like a sheet — mark solved, flag for revision, star the important ones.
          </p>
        </div>
      </div>

      {items.length > 0 && <ProgressBar done={totalDone} total={items.length} />}

      <div className="mt-4">
        <FaqFilters />
      </div>

      {items.length === 0 ? (
        <div className="empty-state mt-6">
          <HelpCircle aria-hidden className="h-10 w-10 text-muted-foreground" />
          <p className="text-muted-foreground font-medium">No questions match yet.</p>
        </div>
      ) : (
        <div className="mt-6 flex flex-col gap-8">
          {Array.from(groups.entries()).map(([groupTag, groupItems]) => {
            const groupDone = groupItems.filter((i) => i.status === "done").length;
            return (
              <section key={groupTag}>
                <div className="mb-2 flex items-center justify-between gap-3">
                  <h2 className="section-title text-lg capitalize">{groupTag}</h2>
                </div>
                <ProgressBar done={groupDone} total={groupItems.length} />
                <ul className="mt-3 flex flex-col divide-y divide-border rounded-md border border-border">
                  {groupItems.map((item) => (
                    <FaqRow item={item} key={item.qna_id} />
                  ))}
                </ul>
              </section>
            );
          })}
        </div>
      )}
    </main>
  );
}
