import type { Metadata } from "next";
import { notFound, redirect } from "next/navigation";

import { DesignProposalPanel } from "@/components/workspace/cohort/design-proposal-panel";
import { MyCheckpointList } from "@/components/workspace/gitlab/my-checkpoint-list";
import { getCurrentUser } from "@/lib/server/auth";
import { getWorkspace } from "@/lib/workspace/server";
import { getWorkspaceCheckpoints, listWorkspaceProposals } from "@/lib/workspace/gitlab-server";
import ROUTES from "@/lib/routes";

export const metadata: Metadata = { title: "Checkpoints" };

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function WorkspaceCheckpointsPage({ params }: PageProps) {
  const { id } = await params;
  const [workspace, currentUser] = await Promise.all([getWorkspace(id), getCurrentUser()]);
  if (!workspace.cohort_id) notFound();
  if (!currentUser) redirect(ROUTES.LOGIN);

  const { checkpoints } = await getWorkspaceCheckpoints(id);
  const proposalCheckpoints = checkpoints.filter((cp) => cp.kind === "design_review" || cp.kind === "architecture_review");
  const proposalLists = await Promise.all(proposalCheckpoints.map((cp) => listWorkspaceProposals(id, cp.checkpoint_id)));

  return (
    <div className="flex flex-col gap-6">
      <h1 className="page-title">Checkpoints</h1>

      {workspace.provision_status === "failed" && workspace.provision_error && (
        <p className="text-sm text-destructive">{workspace.provision_error}</p>
      )}

      <section className="card-base flex flex-col gap-4 p-6">
        <h2 className="section-title">Team checkpoints</h2>
        <MyCheckpointList checkpoints={checkpoints} />
      </section>

      {proposalCheckpoints.length > 0 && (
        <section className="card-base flex flex-col gap-6 p-6">
          <h2 className="section-title">Design proposals</h2>
          {proposalCheckpoints.map((cp, i) => (
            <div className="flex flex-col gap-2" key={cp.checkpoint_id}>
              <span className="text-sm font-semibold">{cp.title}</span>
              <DesignProposalPanel
                checkpointId={cp.checkpoint_id}
                currentUserId={currentUser.id}
                proposals={proposalLists[i]}
                workspaceId={id}
              />
            </div>
          ))}
        </section>
      )}
    </div>
  );
}
