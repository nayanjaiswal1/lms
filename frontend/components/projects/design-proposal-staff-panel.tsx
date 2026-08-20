"use client";

import * as React from "react";
import { Check, ExternalLink } from "lucide-react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { acceptProposalAction } from "@/app/(app)/projects/actions";
import type { DesignProposalView } from "@/lib/projects/types";

interface DesignProposalStaffPanelProps {
  proposals: DesignProposalView[];
  assignmentId: string;
  teamsById: Record<string, { name: string }>;
}

// Staff view of every team's proposals against one design/architecture
// review checkpoint — grouped by team, ranked by vote count within each
// (ListAllDesignProposals already orders that way server-side).
export function DesignProposalStaffPanel({ proposals, assignmentId, teamsById }: DesignProposalStaffPanelProps) {
  const router = useRouter();
  const [pendingId, setPendingId] = React.useState<string | null>(null);

  if (proposals.length === 0) {
    return <p className="text-sm text-muted-foreground">No proposals submitted yet.</p>;
  }

  async function handleAccept(proposalId: string) {
    setPendingId(proposalId);
    const result = await acceptProposalAction(proposalId, assignmentId);
    setPendingId(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Proposal accepted.");
    router.refresh();
  }

  const byTeam = new Map<string, DesignProposalView[]>();
  for (const p of proposals) {
    byTeam.set(p.team_id, [...(byTeam.get(p.team_id) ?? []), p]);
  }

  return (
    <div className="flex flex-col gap-4">
      {[...byTeam.entries()].map(([teamId, teamProposals]) => (
        <div className="flex flex-col gap-2" key={teamId}>
          <span className="text-xs font-semibold text-muted-foreground">{teamsById[teamId]?.name ?? teamId}</span>
          <ul className="divide-y divide-border rounded-md border border-border">
            {teamProposals.map((p) => (
              <li className="flex flex-wrap items-center justify-between gap-2 px-3 py-2.5 text-sm" key={p.id}>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-1.5">
                    <span className="font-medium">{p.title}</span>
                    {p.link && (
                      <a className="text-muted-foreground hover:text-foreground" href={p.link} rel="noreferrer" target="_blank">
                        <ExternalLink aria-hidden className="h-3 w-3" />
                      </a>
                    )}
                  </div>
                  {p.description && <p className="truncate text-xs text-muted-foreground">{p.description}</p>}
                </div>
                <Badge variant="outline">{p.vote_count} vote{p.vote_count === 1 ? "" : "s"}</Badge>
                {p.is_accepted ? (
                  <Badge>
                    <Check aria-hidden className="mr-1 h-3 w-3" />
                    Accepted
                  </Badge>
                ) : (
                  <Button disabled={pendingId === p.id} size="sm" variant="outline" onClick={() => handleAccept(p.id)}>
                    Accept
                  </Button>
                )}
              </li>
            ))}
          </ul>
        </div>
      ))}
    </div>
  );
}
