import type { Metadata } from "next";
import { NavHubGrid } from "@/components/shared/nav-hub-grid";

export const metadata: Metadata = { title: "Instructor" };

export default function TeachHubPage() {
  return (
    <main className="page-container">
      <div className="page-header">
        <div>
          <h1 className="page-title">Instructor</h1>
          <p className="text-sm text-muted-foreground">Course authoring, assessments, question bank, and mentoring in one place.</p>
        </div>
      </div>

      <NavHubGrid catalogue="teach" />
    </main>
  );
}
