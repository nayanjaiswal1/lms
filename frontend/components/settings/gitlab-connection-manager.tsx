"use client";

import { toast } from "sonner";
import { GitBranch } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { disconnectGitlabAction } from "@/app/(app)/settings/integrations/actions";

export interface GitlabConnectionStatus {
  connected: boolean;
  gitlab_username?: string;
  status?: string;
  scopes?: string[];
  last_used_at?: string | null;
  created_at?: string | null;
}

function formatDate(iso: string | null | undefined): string {
  if (!iso) return "Never";
  return new Date(iso).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
}

interface GitlabConnectionManagerProps {
  connection: GitlabConnectionStatus;
  installationConnected: boolean;
}

export function GitlabConnectionManager({ connection, installationConnected }: GitlabConnectionManagerProps) {
  // Full page navigation to the backend's own OAuth-redirect route (like
  // social-login-buttons.tsx's Google/GitHub buttons) — a raw <a>, not
  // next/link, since this crosses to a different origin in most deploys.
  const apiUrl = process.env.NEXT_PUBLIC_API_URL ?? "";

  async function handleDisconnect() {
    const result = await disconnectGitlabAction();
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Disconnected from GitLab.");
  }

  return (
    <section aria-labelledby="gitlab-connection-heading" className="card-base p-6 space-y-5">
      <div>
        <h2 className="text-lg font-semibold text-foreground" id="gitlab-connection-heading">
          GitLab
        </h2>
        <p className="mt-1 text-sm text-muted-foreground">
          Connect your own GitLab account so commits, merge requests, and reviews on project work are
          attributed to you instead of a shared bot identity.
        </p>
      </div>

      {!installationConnected ? (
        <p className="text-sm text-muted-foreground empty-state py-6">
          Your organization hasn&apos;t connected GitLab yet. Ask an admin to set it up in the section
          below before you can connect your own account.
        </p>
      ) : connection.connected ? (
        <div className="flex flex-wrap items-center justify-between gap-4 rounded-lg border border-border p-4">
          <div className="min-w-0 flex items-center gap-3">
            <GitBranch aria-hidden className="h-8 w-8 flex-shrink-0 text-primary" />
            <div className="min-w-0">
              <p className="text-sm font-medium text-foreground truncate">@{connection.gitlab_username}</p>
              <p className="text-xs text-muted-foreground">
                Connected {formatDate(connection.created_at)} · Last used {formatDate(connection.last_used_at)}
              </p>
              <div className="mt-1 flex flex-wrap gap-1">
                <Badge variant={connection.status === "active" ? "secondary" : "destructive"}>
                  {connection.status}
                </Badge>
                {connection.scopes?.map((scope) => (
                  <Badge key={scope} variant="outline">{scope}</Badge>
                ))}
              </div>
            </div>
          </div>
          <Button
            className="touch-target"
            onClick={handleDisconnect}
            size="sm"
            variant="outline"
          >
            Disconnect
          </Button>
        </div>
      ) : (
        <Button asChild disabled={!apiUrl}>
          <a href={`${apiUrl}/api/gitlab/connect`}>
            <GitBranch aria-hidden className="mr-2 h-4 w-4" />
            Connect GitLab
          </a>
        </Button>
      )}
    </section>
  );
}
