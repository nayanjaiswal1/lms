import type { Metadata } from "next";
import { CreateOrgForm } from "@/app/org/create/create-org-form";

export const metadata: Metadata = { title: "Create Organization" };

export default function CreateOrgPage() {
  return (
    // eslint-disable-next-line no-restricted-syntax -- standalone onboarding page outside the (app) shell, no .app-content ancestor to supply vertical padding
    <main className="page-container-sm py-16">
      <div className="mx-auto max-w-md">
        <h1 className="page-title mb-2">Create Organization</h1>
        <p className="mb-8 text-muted-foreground">Set up a workspace for your team.</p>
        <div className="card-base p-6">
          <CreateOrgForm />
        </div>
      </div>
    </main>
  );
}
