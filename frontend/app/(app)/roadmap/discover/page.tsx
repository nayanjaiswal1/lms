import { Suspense } from "react";
import { Compass } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { StartRoadmapButton } from "@/components/roadmap/start-roadmap-button";
import { listPublicRoadmaps } from "@/lib/server/roadmap";

export const metadata = { title: "Discover Roadmaps — MindForge" };

async function PublicRoadmapList() {
  const roadmaps = await listPublicRoadmaps();

  if (roadmaps.length === 0) {
    return (
      <div className="empty-state py-16">
        <Compass aria-hidden className="h-12 w-12 text-muted-foreground" />
        <p className="mt-3 text-sm text-muted-foreground">
          No public roadmaps yet. Once someone shares one, it shows up here for anyone to start.
        </p>
      </div>
    );
  }

  return (
    <ol aria-label="Public roadmaps" className="card-grid">
      {roadmaps.map((rm) => (
        <li className="card-base flex flex-col gap-3 p-6" key={rm.id}>
          <div className="flex flex-col gap-1.5">
            <span className="font-medium">{rm.title}</span>
            <p className="line-clamp-2 text-sm text-muted-foreground">{rm.goal_description}</p>
          </div>
          <div className="flex flex-wrap gap-2">
            {rm.target_role && <Badge variant="outline">{rm.target_role}</Badge>}
            {rm.skill_level && <Badge variant="outline">{rm.skill_level}</Badge>}
            <Badge variant="outline">{rm.module_count} modules</Badge>
          </div>
          <StartRoadmapButton roadmapId={rm.id} />
        </li>
      ))}
    </ol>
  );
}

export default function DiscoverRoadmapsPage() {
  return (
    <main className="page-container py-8">
      <div className="page-header">
        <h1 className="page-title">Discover Roadmaps</h1>
      </div>
      <p className="mb-6 text-muted-foreground">
        Browse roadmaps other learners have shared and start one instantly — no wait, no AI call, just a
        ready-made path you can make your own.
      </p>
      <Suspense fallback={<Skeleton className="h-64 rounded-lg" />}>
        <PublicRoadmapList />
      </Suspense>
    </main>
  );
}
