import { Suspense } from "react";
import Link from "next/link";
import { Compass } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { listPublicRoadmapsAnon } from "@/lib/server/roadmap-public";
import ROUTES from "@/lib/routes";

export const metadata = { title: "Discover Roadmaps" };

async function PublicRoadmapList() {
  const roadmaps = await listPublicRoadmapsAnon();

  if (roadmaps.length === 0) {
    return (
      <div className="empty-state py-16">
        <Compass aria-hidden className="h-12 w-12 text-muted-foreground" />
        <p className="mt-3 text-sm text-muted-foreground">No public roadmaps yet.</p>
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
          <Button asChild className="w-fit" size="sm" variant="secondary">
            <Link href={ROUTES.publicRoadmap(rm.id)}>View roadmap</Link>
          </Button>
        </li>
      ))}
    </ol>
  );
}

export default function PublicRoadmapsPage() {
  return (
    <main className="page-container">
      <div className="page-header">
        <h1 className="section-title">Discover Roadmaps</h1>
      </div>
      <p className="mb-6 text-muted-foreground">
        Browse structured learning paths shared by the MindForge community — free to view.{" "}
        <Link className="underline" href={ROUTES.REGISTER}>
          Sign up
        </Link>{" "}
        to start one and track your own progress.
      </p>
      <Suspense fallback={<Skeleton className="h-64 rounded-lg" />}>
        <PublicRoadmapList />
      </Suspense>
    </main>
  );
}
