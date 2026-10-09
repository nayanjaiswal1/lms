"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { ExternalLink, GitBranch } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { provisionGitlabAction } from "@/lib/workspace/phase4-actions";
import type { GitlabInstallationOption, ProjectDetail } from "@/lib/workspace/types";

const DEFAULT_INSTALLATION = "default";

interface GitlabProvisionSectionProps {
  workspaceId: string;
  project: ProjectDetail;
  installations: GitlabInstallationOption[];
}

/** Provisions the workspace's GitLab repo and shows its links + status.
 * Only shown while gitlab_enabled is on. */
export function GitlabProvisionSection({ workspaceId, project, installations }: GitlabProvisionSectionProps) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [installationId, setInstallationId] = useState(DEFAULT_INSTALLATION);

  if (!project.gitlab_enabled) return null;

  function provision() {
    startTransition(async () => {
      const result = await provisionGitlabAction(workspaceId, installationId === DEFAULT_INSTALLATION ? undefined : installationId);
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
        {project.provision_status && <Badge variant={project.provision_error ? "destructive" : "outline"}>{project.provision_status}</Badge>}
      </div>
      {project.provision_error && <p className="text-sm text-destructive">{project.provision_error}</p>}
      {project.gitlab_web_url && (
        <div className="flex flex-wrap gap-4 text-sm">
          <a className="inline-flex items-center gap-1 text-primary hover:underline" href={project.gitlab_web_url} rel="noreferrer" target="_blank">
            Repository <ExternalLink aria-hidden className="h-3.5 w-3.5" />
          </a>
          {project.gitlab_pages_url && (
            <a className="inline-flex items-center gap-1 text-primary hover:underline" href={project.gitlab_pages_url} rel="noreferrer" target="_blank">
              Pages <ExternalLink aria-hidden className="h-3.5 w-3.5" />
            </a>
          )}
        </div>
      )}
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
          {installations.length > 0 && (
            <div className="flex max-w-sm flex-col gap-1.5">
              <Label htmlFor="gitlab-installation">GitLab installation</Label>
              <Select value={installationId} onValueChange={setInstallationId}>
                <SelectTrigger id="gitlab-installation">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value={DEFAULT_INSTALLATION}>Organization default</SelectItem>
                  {installations.map((i) => (
                    <SelectItem key={i.id} value={i.id}>
                      {i.is_default ? `${i.name} (default)` : i.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          )}
          <Button className="w-fit" disabled={pending} onClick={provision}>
            {pending ? "Creating…" : "Create GitLab repository"}
          </Button>
        </>
      )}
    </div>
  );
}
