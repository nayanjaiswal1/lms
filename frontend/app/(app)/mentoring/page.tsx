import { Suspense } from "react";
import Link from "next/link";
import { Users, MessageSquare, ArrowRight } from "lucide-react";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import { StatCard } from "@/components/shared/stat-card";
import { getBatches, getBatchMembers, type Batch } from "@/lib/server/batches";
import { getBatchMessages } from "@/lib/server/messaging";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Mentoring Overview" };

interface BatchSummary {
  batch: Batch;
  memberCount: number;
  unresolvedCount: number;
}

async function loadBatchSummaries(): Promise<BatchSummary[]> {
  const batches = await getBatches();

  return Promise.all(
    batches.map(async (batch) => {
      const [members, unresolved] = await Promise.all([
        getBatchMembers(batch.id).catch(() => []),
        getBatchMessages(batch.id, { type: "question", unresolved: true, limit: 50 }).catch(() => []),
      ]);
      return { batch, memberCount: members.length, unresolvedCount: unresolved.length };
    }),
  );
}

async function MentoringOverviewContent() {
  const summaries = await loadBatchSummaries();
  const totalStudents = summaries.reduce((sum, s) => sum + s.memberCount, 0);
  const totalUnresolved = summaries.reduce((sum, s) => sum + s.unresolvedCount, 0);

  return (
    <>
      <div className="grid-stats mb-8">
        <StatCard icon={Users} label="Batches" value={String(summaries.length)} unit="total" />
        <StatCard icon={Users} label="Students" value={String(totalStudents)} unit="total" />
        <StatCard
          icon={MessageSquare}
          label="Unresolved questions"
          value={String(totalUnresolved)}
          unit={totalUnresolved === 1 ? "question" : "questions"}
          highlighted={totalUnresolved > 0}
          href={ROUTES.COHORT_GROUPS}
        />
      </div>

      <div className="mb-4 flex items-center justify-between gap-4">
        <h2 className="section-title">Your batches</h2>
        <Link
          href={ROUTES.BATCHES}
          className="flex items-center gap-1 text-sm text-primary hover:underline"
        >
          View all <ArrowRight className="h-3.5 w-3.5" aria-hidden />
        </Link>
      </div>

      {summaries.length === 0 ? (
        <div className="empty-state py-16">
          <Users aria-hidden className="h-12 w-12 text-muted-foreground" />
          <p className="mt-3 text-sm text-muted-foreground">You are not assigned to any batches yet.</p>
        </div>
      ) : (
        <ol className="flex flex-col gap-3" aria-label="Batches">
          {summaries.map(({ batch, memberCount, unresolvedCount }) => (
            <li key={batch.id}>
              <Link href={ROUTES.batch(batch.id)} className="card-interactive flex items-center gap-4 p-5">
                <div className="flex flex-1 flex-col gap-1">
                  <div className="flex items-center gap-2">
                    <span className="font-medium">{batch.name}</span>
                    <Badge variant={batch.status === "active" ? "default" : "secondary"}>
                      {batch.status}
                    </Badge>
                  </div>
                  <p className="text-sm text-muted-foreground">
                    {memberCount} student{memberCount !== 1 ? "s" : ""}
                    {unresolvedCount > 0 &&
                      ` · ${unresolvedCount} unresolved question${unresolvedCount !== 1 ? "s" : ""}`}
                  </p>
                </div>
              </Link>
            </li>
          ))}
        </ol>
      )}
    </>
  );
}

export default function MentoringOverviewPage() {
  return (
    <main className="page-container">
      <div className="mb-8 flex flex-col gap-2">
        <h1>Mentoring overview</h1>
        <p className="text-muted-foreground">Your batches, students, and open questions at a glance.</p>
      </div>
      <Suspense fallback={<Skeleton className="h-64 rounded-lg" />}>
        <MentoringOverviewContent />
      </Suspense>
    </main>
  );
}
