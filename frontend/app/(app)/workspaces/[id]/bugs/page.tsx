import type { Metadata } from "next";

import { BugTriageQueue } from "@/components/workspace/bugs/bug-triage-queue";
import { listWorkItems } from "@/lib/workspace/items-server";
import { listWorkspaceMembers } from "@/lib/workspace/server";

export const metadata: Metadata = {
  title: "Bug triage",
};

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function WorkspaceBugsPage({ params }: PageProps) {
  const { id } = await params;
  const [bugsPage, members] = await Promise.all([
    listWorkItems(id, { type: "bug", limit: 100 }),
    listWorkspaceMembers(id),
  ]);

  // ponytail: no dedicated "untriaged" backend filter exists yet — filter the
  // (capped) bug list client-side. Add a `severity=none` query param to
  // ListWorkItems if the queue regularly exceeds this page size.
  const untriaged = bugsPage.items
    .filter((b) => b.severity === null)
    .sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());

  return (
    <div className="flex flex-col gap-4">
      <p className="text-sm text-muted-foreground">Bugs waiting on a severity call, oldest first.</p>
      <BugTriageQueue bugs={untriaged} members={members} workspaceId={id} />
    </div>
  );
}
