import { NewRoadmapForm } from "@/components/roadmap/new-roadmap-form";
import { getRoadmapProfileDefaults } from "@/lib/server/roadmap";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import ROUTES from "@/lib/routes";

export const metadata = { title: "New Roadmap" };

export default async function NewRoadmapPage() {
  const defaults = await getRoadmapProfileDefaults().catch(() => null);

  return (
    <main className="page-container-sm">
      <Breadcrumb items={[{ href: ROUTES.ROADMAP, label: "Roadmap" }, { label: "New" }]} />
      <div className="page-header">
        <h1 className="section-title">Build My Roadmap</h1>
      </div>
      <p className="mb-8 text-muted-foreground">
        Describe what you want to achieve. AI will build a personalized phase → milestone → module
        learning path — coding, DSA, labs, and projects — linked into MindForge&apos;s own courses and labs
        wherever a good match exists.
      </p>
      <NewRoadmapForm defaults={defaults} />
    </main>
  );
}
