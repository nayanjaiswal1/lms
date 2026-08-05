import { notFound } from "next/navigation";
import { Sparkles, TriangleAlert } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { RoadmapView } from "@/components/roadmap/roadmap-view";
import { RegenerateRoadmapButton } from "@/components/roadmap/regenerate-roadmap-button";
import { ArchiveRoadmapButton } from "@/components/roadmap/archive-roadmap-button";
import { PublishRoadmapToggle } from "@/components/roadmap/publish-roadmap-toggle";
import { DeleteRoadmapButton } from "@/components/roadmap/delete-roadmap-button";
import { getRoadmap } from "@/lib/server/roadmap";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import { IconMessage } from "@/components/shared/icon-message";
import ROUTES from "@/lib/routes";

interface Props {
  params: Promise<{ id: string }>;
}

export async function generateMetadata({ params }: Props) {
  const { id } = await params;
  const roadmap = await getRoadmap(id).catch(() => null);
  if (!roadmap) return { title: "Roadmap" };
  return { title: roadmap.title };
}

export default async function RoadmapDetailPage({ params }: Props) {
  const { id } = await params;
  const roadmap = await getRoadmap(id).catch(() => null);
  if (!roadmap) notFound();

  const pct = roadmap.module_count > 0
    ? Math.round((roadmap.completed_count / roadmap.module_count) * 100)
    : 0;

  return (
    <main className="page-container">
      {/* ponytail: meta-refresh polls the server component while generating —
          no client interval/useEffect needed, and it stops on its own once
          status leaves 'generating' since this tag is then simply absent. */}
      {roadmap.status === "generating" && <meta content="3" httpEquiv="refresh" />}

      <Breadcrumb items={[{ href: ROUTES.ROADMAP, label: "Roadmap" }, { label: roadmap.title }]} />

      <div className="flex flex-col gap-1 mb-4">
        <div className="flex flex-wrap items-center gap-2">
          <h1 className="section-title">{roadmap.title}</h1>
          <Badge variant="outline">{roadmap.status}</Badge>
        </div>
        <p className="text-sm text-muted-foreground">{roadmap.goal_description}</p>
      </div>

      {roadmap.status === "generating" && (
        <IconMessage className="ai-surface p-6" icon={Sparkles} size="md" tone="ai" variant="plain">
          AI is building your personalized roadmap — phases, milestones, and modules tailored to your
          goal. This page refreshes automatically.
        </IconMessage>
      )}

      {roadmap.status === "failed" && (
        <div className="flex flex-col gap-3 rounded-lg border border-destructive/30 bg-destructive/10 p-6">
          <div className="flex items-center gap-2 text-destructive">
            <TriangleAlert aria-hidden className="h-5 w-5" />
            <span className="font-medium">Generation failed</span>
          </div>
          <p className="text-sm text-muted-foreground">
            {roadmap.generation_error ?? "Something went wrong while generating this roadmap."}
          </p>
          <div className="flex flex-wrap gap-2">
            <RegenerateRoadmapButton roadmapId={roadmap.id} />
            <DeleteRoadmapButton roadmapId={roadmap.id} />
          </div>
        </div>
      )}

      {(roadmap.status === "active" || roadmap.status === "completed" || roadmap.status === "archived") && (
        <>
          <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center gap-2">
              <div className="progress-track w-40">
                { }
                <div className="progress-fill" style={{ "--progress": `${pct}%` } as React.CSSProperties} />
              </div>
              <span className="text-sm text-muted-foreground">
                {roadmap.completed_count}/{roadmap.module_count} modules done
              </span>
            </div>
            <div className="flex flex-wrap gap-2">
              <RegenerateRoadmapButton roadmapId={roadmap.id} />
              <PublishRoadmapToggle isPublic={roadmap.is_public} roadmapId={roadmap.id} />
              <ArchiveRoadmapButton archived={roadmap.status === "archived"} roadmapId={roadmap.id} />
              <DeleteRoadmapButton roadmapId={roadmap.id} />
            </div>
          </div>
          <RoadmapView roadmap={roadmap} />
        </>
      )}
    </main>
  );
}
