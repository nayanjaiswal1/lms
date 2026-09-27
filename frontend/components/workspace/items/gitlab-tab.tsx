import { ExternalLink, GitBranch, GitCommitHorizontal, GitPullRequest } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import type { GitlabLink } from "@/lib/workspace/types";

const KIND_ICON = { branch: GitBranch, mr: GitPullRequest, commit: GitCommitHorizontal } as const;

const PIPELINE_BADGE_CLASS: Record<string, string> = {
  success: "badge-success",
  failed: "badge-destructive",
  running: "badge-info",
  pending: "badge-muted",
  canceled: "badge-muted",
};

function PipelineBadge({ status }: { status: string | null }) {
  if (!status) return null;
  return <Badge className={cn(PIPELINE_BADGE_CLASS[status] ?? "badge-muted")} variant="outline">{status}</Badge>;
}

function SizeBadge({ additions, deletions }: { additions: number | null; deletions: number | null }) {
  if (additions === null && deletions === null) return null;
  const total = (additions ?? 0) + (deletions ?? 0);
  // Mirrors backend MRSizeFlagLines (400) — a large MR gets flagged the same
  // way the dashboard's Quality.LargeMRs count does.
  const large = total > 400;
  return (
    <span className={cn("text-xs", large ? "text-warning-foreground" : "text-muted-foreground")}>
      +{additions ?? 0} / −{deletions ?? 0}
    </span>
  );
}

interface GitlabTabProps {
  links: GitlabLink[];
}

export function GitlabTab({ links }: GitlabTabProps) {
  if (links.length === 0) {
    return (
      <div className="empty-state py-8">
        <GitBranch aria-hidden className="empty-state-icon" />
        <p className="text-sm text-muted-foreground">No GitLab activity linked to this item yet.</p>
        <p className="text-xs text-muted-foreground">
          Mention this item&apos;s key (e.g. in a commit message, branch name, or merge request) to link it automatically.
        </p>
      </div>
    );
  }

  return (
    <ul className="flex flex-col gap-2">
      {links.map((link) => {
        const Icon = KIND_ICON[link.kind];
        return (
          <li className="card-base flex items-center gap-3 p-3" key={link.id}>
            <Icon aria-hidden className="h-4 w-4 shrink-0 text-muted-foreground" />
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium">{link.mr_title ?? link.ref}</p>
              <p className="truncate text-xs text-muted-foreground">
                {link.kind === "mr" ? `Merge request · ${link.mr_state}` : link.kind === "branch" ? "Branch" : "Commit"}
              </p>
            </div>
            <SizeBadge additions={link.additions} deletions={link.deletions} />
            <PipelineBadge status={link.pipeline_status} />
            {link.sync_status === "pending" && <Badge className="badge-warning" variant="outline">Sync pending</Badge>}
            {link.sync_status === "failed" && <Badge className="badge-destructive" variant="outline">Sync failed</Badge>}
            {link.mr_web_url && (
              <a
                aria-label="Open in GitLab"
                className="text-muted-foreground transition-colors duration-fast hover:text-foreground"
                href={link.mr_web_url}
                rel="noopener noreferrer"
                target="_blank"
              >
                <ExternalLink aria-hidden className="h-4 w-4" />
              </a>
            )}
          </li>
        );
      })}
    </ul>
  );
}
