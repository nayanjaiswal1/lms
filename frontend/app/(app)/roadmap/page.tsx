import { Suspense } from "react";
import Link from "next/link";
import { Compass, Plus, Map } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { listRoadmaps } from "@/lib/server/roadmap";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Roadmap" };

const STATUS_BADGE: Record<string, string> = {
  generating: "border border-border text-muted-foreground",
  active:     "bg-primary text-primary-foreground",
  completed:  "bg-muted text-muted-foreground",
  archived:   "border border-border text-muted-foreground",
  failed:     "border border-destructive text-destructive",
};

async function RoadmapList() {
  const roadmaps = await listRoadmaps();

  if (roadmaps.length === 0) {
    return (
      <div className="empty-state py-16">
        <Map aria-hidden className="h-12 w-12 text-muted-foreground" />
        <p className="mt-3 text-sm text-muted-foreground">
          No roadmaps yet. State a goal and AI will build a personalized phase-by-phase learning path.
        </p>
        <Button asChild className="mt-4">
          <Link href={ROUTES.ROADMAP_NEW}>Build my roadmap</Link>
        </Button>
      </div>
    );
  }

  return (
    <ol aria-label="Your roadmaps" className="flex flex-col gap-3">
      {roadmaps.map((rm) => {
        const pct = rm.module_count > 0 ? Math.round((rm.completed_count / rm.module_count) * 100) : 0;
        return (
          <li key={rm.id}>
            <Link className="card-interactive flex items-center gap-4 p-4" href={ROUTES.roadmap(rm.id)}>
              <div className="flex flex-1 flex-col gap-1.5">
                <div className="flex items-center gap-2">
                  <span className="font-medium">{rm.title}</span>
                  <Badge className={STATUS_BADGE[rm.status] ?? ""} variant="outline">
                    {rm.status}
                  </Badge>
                  {rm.is_public && <Badge variant="outline">Public</Badge>}
                </div>
                {rm.status === "active" || rm.status === "completed" ? (
                  <div className="flex items-center gap-2">
                    <div className="progress-track w-32">
                      {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width needs inline style */}
                      <div className="progress-fill" style={{ "--progress": `${pct}%` } as React.CSSProperties} />
                    </div>
                    <span className="text-xs text-muted-foreground">
                      {rm.completed_count}/{rm.module_count} done
                    </span>
                  </div>
                ) : (
                  <span className="text-xs text-muted-foreground">
                    {new Date(rm.created_at).toLocaleDateString()}
                  </span>
                )}
              </div>
            </Link>
          </li>
        );
      })}
    </ol>
  );
}

export default function RoadmapPage() {
  return (
    <main className="page-container">
      <div className="page-header">
        <h1 className="page-title">Roadmap</h1>
        <div className="flex gap-2">
          <Button asChild variant="outline">
            <Link href={ROUTES.ROADMAP_DISCOVER}>
              <Compass aria-hidden className="mr-2 h-4 w-4" />
              Discover
            </Link>
          </Button>
          <Button asChild>
            <Link href={ROUTES.ROADMAP_NEW}>
              <Plus aria-hidden className="mr-2 h-4 w-4" />
              New roadmap
            </Link>
          </Button>
        </div>
      </div>
      <Suspense fallback={<Skeleton className="h-64 rounded-lg" />}>
        <RoadmapList />
      </Suspense>
    </main>
  );
}
