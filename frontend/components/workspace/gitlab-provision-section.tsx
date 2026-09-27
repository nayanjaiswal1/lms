"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { GitBranch } from "lucide-react";

import { Button } from "@/components/ui/button";
import { provisionGitlabAction } from "@/lib/workspace/phase4-actions";
import type { Project } from "@/lib/workspace/types";

interface GitlabProvisionSectionProps {
  workspaceId: string;
  project: Project;
}

/** contract-phase4.md D8: gives the project its own GitLab repo the first
 * time — only shown while gitlab_enabled is on and no repo exists yet. */
export function GitlabProvisionSection({ workspaceId, project }: GitlabProvisionSectionProps) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();

  if (!project.gitlab_enabled) return null;

  function provision() {
    startTransition(async () => {
      const result = await provisionGitlabAction(workspaceId);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success("GitLab repository created.");
      router.refresh();
    });
  }

  return (
    <div className="card-base flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <GitBranch aria-hidden className="h-5 w-5 text-muted-foreground" />
        <h2 className="subsection-title">GitLab</h2>
      </div>
      {project.team_id ? (
        <p className="text-sm text-muted-foreground">
          This project has its own GitLab repository. Commits, branches and merge requests that mention an item&apos;s
          key (e.g. {project.key_prefix}-12) link to it automatically.
        </p>
      ) : (
        <>
          <p className="text-sm text-muted-foreground">
            Create a private GitLab repository for this project. Active members are added automatically —
            owners/managers as maintainers, everyone else as developers.
          </p>
          <Button className="w-fit" disabled={pending} onClick={provision}>
            {pending ? "Creating…" : "Create GitLab repository"}
          </Button>
        </>
      )}
    </div>
  );
}
