import { NewRoadmapForm } from "@/components/roadmap/new-roadmap-form";
import { getRoadmapProfileDefaults } from "@/lib/server/roadmap";

export const metadata = { title: "New Roadmap — MindForge" };

export default async function NewRoadmapPage() {
  const defaults = await getRoadmapProfileDefaults().catch(() => null);

  return (
    <main className="page-container-sm">
      <div className="page-header">
        <h1 className="page-title">Build My Roadmap</h1>
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
