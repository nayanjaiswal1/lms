import type { Metadata } from "next";
import { LearnHubGrid } from "@/components/learn/learn-hub-grid";

export const metadata: Metadata = { title: "Learn" };

export default function LearnHubPage() {
  return (
    <main className="page-container py-6">
      <div className="page-header">
        <div>
          <h1 className="page-title">Learn</h1>
          <p className="text-sm text-muted-foreground">Courses, assessments, practice, and every learning tool in one place.</p>
        </div>
      </div>

      <LearnHubGrid />
    </main>
  );
}
