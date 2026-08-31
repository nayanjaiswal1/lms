import Link from "next/link";
import { notFound } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { RoadmapTree } from "@/components/roadmap/roadmap-tree";
import { getPublicRoadmapAnon } from "@/lib/server/roadmap-public";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { id } = await params;
  const roadmap = await getPublicRoadmapAnon(id).catch(() => null);
  if (!roadmap) return { title: "Roadmap" };
  return { title: roadmap.title };
}

export default async function PublicRoadmapDetailPage({ params }: Props) {
  const { id } = await params;
  const roadmap = await getPublicRoadmapAnon(id).catch(() => null);
  if (!roadmap) notFound();

  return (
    <main className="page-container">
      <div className="mb-4 flex flex-col gap-1">
        <div className="flex flex-wrap items-center gap-2">
          <h1 className="section-title">{roadmap.title}</h1>
          {roadmap.target_role && <Badge variant="outline">{roadmap.target_role}</Badge>}
          {roadmap.skill_level && <Badge variant="outline">{roadmap.skill_level}</Badge>}
        </div>
        <p className="text-sm text-muted-foreground">{roadmap.goal_description}</p>
      </div>

      <div className="mb-6 flex flex-wrap items-center justify-between gap-3 rounded-lg border border-border bg-muted/40 p-4">
        <span className="text-sm text-muted-foreground">
          Viewing read-only. Sign up to track your own progress through this roadmap.
        </span>
        <Button asChild size="sm">
          <Link href={ROUTES.REGISTER}>Sign up free</Link>
        </Button>
      </div>

      <RoadmapTree readOnly roadmap={roadmap} />
    </main>
  );
}
