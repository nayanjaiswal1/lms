"use client";

import { useState, useTransition } from "react";
import Link from "next/link";
import { toast } from "sonner";
import { FileText } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { useProjectRole } from "@/components/workspace/project-role-provider";
import { approveBriefAction, createBriefAction } from "@/lib/workspace/phase3-actions";
import { BRIEF_STATUS_LABEL } from "@/lib/workspace/roles";
import type { BriefApproval, BriefView as BriefViewData } from "@/lib/workspace/types";
import ROUTES from "@/lib/routes";

const APPROVER_ROLE_LABEL: Record<BriefApproval["approver_role"], string> = {
  owner: "Owner",
  manager: "Manager",
  track_lead: "Track lead",
};

interface BriefViewProps {
  workspaceId: string;
  wikiSpaceSlug: string | null;
  brief: BriefViewData;
}

export function BriefView({ workspaceId, wikiSpaceSlug, brief }: BriefViewProps) {
  const { atLeast, ledTrackIds } = useProjectRole();
  const [current, setCurrent] = useState(brief);
  const [pending, startTransition] = useTransition();

  const canCreate = atLeast("manager") || ledTrackIds.length > 0;

  function handleCreate() {
    startTransition(async () => {
      const result = await createBriefAction(workspaceId);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      if (result.data) setCurrent(result.data);
      toast.success("Brief page created.");
    });
  }

  function handleApprove() {
    startTransition(async () => {
      const result = await approveBriefAction(workspaceId);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      if (result.data) setCurrent(result.data);
      toast.success("Approval recorded.");
    });
  }

  const approveButton = (
    <Button disabled={pending || !current.can_approve} onClick={handleApprove}>
      {pending ? "Recording…" : "Approve brief"}
    </Button>
  );

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-wrap items-center gap-2">
        <Badge variant="outline">v{current.requirement_version}</Badge>
        <Badge variant="secondary">{BRIEF_STATUS_LABEL[current.brief_status]}</Badge>
      </div>

      {current.page_id ? (
        <div className="card-base flex flex-col gap-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <Link
              className="flex items-center gap-2 text-sm font-medium text-primary hover:underline"
              href={wikiSpaceSlug && current.page_slug ? ROUTES.wikiPage(wikiSpaceSlug, current.page_slug) : "#"}
            >
              <FileText aria-hidden className="h-4 w-4" />
              Open the brief page (v{current.page_version})
            </Link>
            {current.can_approve ? (
              approveButton
            ) : (
              <Tooltip>
                <TooltipTrigger asChild><span>{approveButton}</span></TooltipTrigger>
                <TooltipContent>{current.approve_blocker || "You can't approve this brief yet."}</TooltipContent>
              </Tooltip>
            )}
          </div>

          <div className="flex flex-col gap-2">
            <h2 className="text-sm font-medium text-muted-foreground">Approvals</h2>
            {current.approvals.length === 0 ? (
              <p className="text-sm text-muted-foreground">No approvals yet.</p>
            ) : (
              <ul className="flex flex-col gap-1.5">
                {current.approvals.map((a) => (
                  <li className="flex items-center justify-between gap-2 text-sm" key={a.approver_id}>
                    <span>
                      {a.approver_name}{" "}
                      <span className="text-xs text-muted-foreground">({APPROVER_ROLE_LABEL[a.approver_role]})</span>
                    </span>
                    <span className="text-xs text-muted-foreground">
                      v{a.wiki_version} · {new Date(a.created_at).toLocaleDateString()}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>
      ) : (
        <div className="empty-state">
          <p className="font-medium text-muted-foreground">No brief page yet.</p>
          {canCreate ? (
            <Button className="mt-3" disabled={pending} onClick={handleCreate}>
              {pending ? "Creating…" : "Create brief"}
            </Button>
          ) : (
            <p className="mt-1 text-sm text-muted-foreground">A manager or track lead needs to write it first.</p>
          )}
        </div>
      )}
    </div>
  );
}
