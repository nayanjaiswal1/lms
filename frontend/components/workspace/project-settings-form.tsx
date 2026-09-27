import { GeneralSettingsForm } from "@/components/workspace/general-settings-form";
import { GitlabProvisionSection } from "@/components/workspace/gitlab-provision-section";
import { ShareLinkSection } from "@/components/workspace/share-link-section";
import { TransferOwnerSection } from "@/components/workspace/transfer-owner-section";
import type { Member, ProjectDetail } from "@/lib/workspace/types";

interface ProjectSettingsFormProps {
  workspaceId: string;
  project: ProjectDetail;
  members: Member[];
}

/** Owner-only settings page body — composes the three settings sections.
 * health_thresholds tuning is left out of Phase 1 (dashboard-era knob, no
 * dashboard to preview it against yet). */
export function ProjectSettingsForm({ workspaceId, project, members }: ProjectSettingsFormProps) {
  return (
    <div className="flex flex-col gap-6">
      <div className="card-base">
        <h2 className="subsection-title mb-4">General</h2>
        <GeneralSettingsForm project={project} workspaceId={workspaceId} />
      </div>
      <GitlabProvisionSection project={project} workspaceId={workspaceId} />
      <ShareLinkSection shareToken={project.share_token} workspaceId={workspaceId} />
      <TransferOwnerSection members={members} workspaceId={workspaceId} />
    </div>
  );
}
