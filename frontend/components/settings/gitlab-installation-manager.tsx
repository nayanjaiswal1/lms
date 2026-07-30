"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { GitlabInstallationCard, type GitlabInstallationStatus } from "@/components/settings/gitlab-installation-card";
import { GitlabInstallationForm } from "@/components/settings/gitlab-installation-form";
import { setGitlabOrgConfigAction } from "@/app/(app)/settings/integrations/actions";

export type { GitlabInstallationStatus } from "@/components/settings/gitlab-installation-card";

export interface GitlabOrgConfig {
  allow_project_override: boolean;
}

interface GitlabInstallationManagerProps {
  installations: GitlabInstallationStatus[];
  orgConfig: GitlabOrgConfig;
}

export function GitlabInstallationManager({ installations, orgConfig }: GitlabInstallationManagerProps) {
  const [showAddForm, setShowAddForm] = useState(installations.length === 0);

  async function handleToggleOverride(checked: boolean) {
    const result = await setGitlabOrgConfigAction(checked);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(checked ? "Project assignments can now pick their own GitLab connection." : "Every project assignment will follow the default connection.");
  }

  return (
    <section aria-labelledby="gitlab-installation-heading" className="card-base p-6 space-y-5">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="text-lg font-semibold text-foreground" id="gitlab-installation-heading">
            GitLab connections
          </h2>
          <p className="mt-1 text-sm text-muted-foreground">
            Connect one or more GitLab instances so members can link their own accounts and
            project assignments can provision real repos. Admin-only.
          </p>
        </div>
        {!showAddForm && (
          <Button size="sm" variant="outline" onClick={() => setShowAddForm(true)}>
            <Plus aria-hidden className="h-4 w-4" /> Add connection
          </Button>
        )}
      </div>

      {installations.length > 0 && (
        <div className="flex items-start gap-3 rounded-lg border border-border p-4 text-sm">
          <Checkbox
            checked={orgConfig.allow_project_override}
            className="mt-0.5"
            id="allow-project-override"
            onCheckedChange={(checked) => handleToggleOverride(checked === true)}
          />
          <label htmlFor="allow-project-override">
            <span className="font-medium text-foreground">Allow project assignments to override the default connection</span>
            <p className="mt-0.5 text-xs text-muted-foreground">
              When off, every assignment uses the default connection above and instructors won&apos;t
              see a connection picker when creating one.
            </p>
          </label>
        </div>
      )}

      <div className="space-y-3">
        {installations.map((installation) => (
          <GitlabInstallationCard installation={installation} key={installation.id} />
        ))}
      </div>

      {showAddForm && (
        <GitlabInstallationForm onDone={() => setShowAddForm(false)} />
      )}
    </section>
  );
}
