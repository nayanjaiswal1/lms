import type { Metadata } from "next";
import { NavHubGrid } from "@/components/shared/nav-hub-grid";
import { PageHeader } from "@/components/shared/page-header";

export const metadata: Metadata = { title: "Instructor" };

export default function TeachHubPage() {
  return (
    <main className="page-container">
      <PageHeader title="Instructor" description="Course authoring, assessments, question bank, and mentoring in one place." />

      <NavHubGrid catalogue="teach" />
    </main>
  );
}
