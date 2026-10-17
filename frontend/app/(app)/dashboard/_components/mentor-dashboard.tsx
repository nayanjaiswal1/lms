import Link from "next/link";
import { Users } from "lucide-react";
import { Suspense } from "react";

import { Button } from "@/components/ui/button";
import { PageHeader } from "@/components/shared/page-header";
import { PERMISSIONS } from "@/lib/auth/permission-codes";
import ROUTES from "@/lib/routes";
import { getBatchProgress, getMyBatches } from "@/lib/server/batches";
import { getTicketQueue } from "@/lib/server/tickets";
import { GradingQueue } from "./grading-queue";
import { DashboardEmptyState } from "./empty-state";
import { DashboardSectionHeader } from "./section-header";
import { ListSkeleton, StatTiles, StatTilesSkeleton } from "./stat-tiles";

const BATCH_LIMIT = 6;

async function loadBatches() {
  return (await getMyBatches()).slice(0, BATCH_LIMIT);
}

async function Overview({ canTickets }: { canTickets: boolean }) {
  const batches = await loadBatches();
  const [tickets, progress] = await Promise.all([
    canTickets ? getTicketQueue("mentorship", { status: "open" }).catch(() => null) : null,
    Promise.all(batches.map((b) => getBatchProgress(b.id).catch(() => []))),
  ]);
  const atRisk = progress.flat().filter((m) => m.status !== "on_track").length;
  const tiles = [
    { label: "Batches", value: batches.length },
    { label: "Students", value: batches.reduce((n, b) => n + b.member_count, 0) },
    { label: "Needing attention", value: atRisk },
  ];
  if (tickets) tiles.push({ label: "Open tickets", value: tickets.length });
  return <StatTiles tiles={tiles} />;
}

async function BatchList() {
  const batches = await loadBatches();
  if (batches.length === 0) {
    return <DashboardEmptyState icon={Users} message="You have no batches yet." />;
  }
  return (
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
      {batches.map((b) => (
        <Link className="card-base card-interactive flex min-w-0 flex-col gap-2 p-6" href={ROUTES.batch(b.id)} key={b.id}>
          <span className="truncate font-medium">{b.name}</span>
          <span className="text-sm text-muted-foreground">{b.member_count} students · {b.status}</span>
        </Link>
      ))}
    </div>
  );
}

export function MentorDashboard({ firstName, perms }: { firstName: string; perms: readonly string[] }) {
  const canTickets = perms.includes(PERMISSIONS.MENTORING.VIEW_TICKETS);
  const canGrade = perms.includes(PERMISSIONS.ASSESSMENTS.VIEW_RESULTS);
  return (
    <main className="page-container">
      <PageHeader description="Your batches and mentees." title={`Welcome back, ${firstName}`}>
        <Button asChild size="sm"><Link href={ROUTES.MENTORING}>Open mentoring</Link></Button>
      </PageHeader>
      <div className="flex flex-col gap-8">
        <Suspense fallback={<StatTilesSkeleton />}>
          <Overview canTickets={canTickets} />
        </Suspense>
        {canGrade && (
          <section>
            <DashboardSectionHeader title="Awaiting review" />
            <Suspense fallback={<ListSkeleton />}>
              <GradingQueue />
            </Suspense>
          </section>
        )}
        <section>
          <DashboardSectionHeader link={{ href: ROUTES.BATCHES, label: "All batches" }} title="Your batches" />
          <Suspense fallback={<ListSkeleton />}>
            <BatchList />
          </Suspense>
        </section>
      </div>
    </main>
  );
}
