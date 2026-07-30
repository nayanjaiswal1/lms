import type { Metadata } from "next";

import { CreatePostForm } from "@/components/interview-exp/create-post-form";
import { Breadcrumb } from "@/components/shared/breadcrumb";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = { title: "Share an interview experience" };

export default function NewInterviewExpPage() {
  return (
    <main className="page-container-sm">
      <Breadcrumb items={[{ href: ROUTES.INTERVIEW_EXP, label: "Interview Experiences" }, { label: "New" }]} />
      <div className="page-header">
        <div>
          <h1 className="section-title">Share an experience</h1>
          <p className="text-sm text-muted-foreground">
            Start with the company and role. You can add rounds and questions afterward — or just ask a
            standalone question with no full write-up.
          </p>
        </div>
      </div>
      <CreatePostForm />
    </main>
  );
}
