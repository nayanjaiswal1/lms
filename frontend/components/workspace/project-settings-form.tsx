import { GeneralSettingsForm } from "@/components/workspace/general-settings-form";
import { GitlabProvisionSection } from "@/components/workspace/gitlab-provision-section";
import { TeamHandoffDialog } from "@/components/workspace/gitlab/team-handoff-dialog";
import { ShareLinkSection } from "@/components/workspace/share-link-section";
import { TransferOwnerSection } from "@/components/workspace/transfer-owner-section";
import type { GitlabInstallationOption, Member, ProjectDetail } from "@/lib/workspace/types";

interface ProjectSettingsFormProps {
  workspaceId: string;
  project: ProjectDetail;
  members: Member[];
  installations: GitlabInstallationOption[];
}

/** Owner-only settings page body — composes the three settings sections.
 * health_thresholds tuning is left out of Phase 1 (dashboard-era knob, no
 * dashboard to preview it against yet). */
export function ProjectSettingsForm({ workspaceId, project, members, installations }: ProjectSettingsFormProps) {
  return (
    <div className="flex flex-col gap-6">
      <div className="card-base">
        <h2 className="subsection-title mb-4">General</h2>
        <GeneralSettingsForm project={project} workspaceId={workspaceId} />
      </div>
      <GitlabProvisionSection installations={installations} project={project} workspaceId={workspaceId} />
      {project.project_status === "completed" && project.team_id && (
        <div className="card-base flex items-center justify-between gap-3">
          <div>
            <h2 className="subsection-title">Hand off repository</h2>
            <p className="text-sm text-muted-foreground">Fork or transfer the repository to another GitLab namespace.</p>
          </div>
          <TeamHandoffDialog memberCount={project.seats_used} title={project.title} workspaceId={workspaceId} />
        </div>
      )}
      <ShareLinkSection shareToken={project.share_token} workspaceId={workspaceId} />
      <TransferOwnerSection members={members} workspaceId={workspaceId} />
    </div>
  );
}
