"use client";

import { useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { AlertTriangle, FileText, RefreshCw } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { ScheduleDesignReviewDialog } from "@/components/workspace/items/schedule-design-review-dialog";
import { useProjectRole } from "@/components/workspace/project-role-provider";
import { DOC_STATUS_LABEL } from "@/lib/workspace/items-constants";
import { reviewDocAction, submitDocAction } from "@/lib/workspace/phase3-actions";
import type { DocView, ItemDetail, Member, ReviewVerdict } from "@/lib/workspace/types";
import ROUTES from "@/lib/routes";

interface DocTabProps {
  workspaceId: string;
  item: ItemDetail;
  doc: DocView;
  members: Member[];
}

const REVIEW_VERDICT_VARIANT: Record<ReviewVerdict, "default" | "destructive" | "outline"> = {
  approved: "default",
  changes_requested: "destructive",
  commented: "outline",
};

// ErrStaleDocVersion's message text (models_phase3.go) — matched to swap the
// generic toast for a persistent "reload" banner instead.
const STALE_MARKER = "changed since you opened it";

/** Feature-only Doc tab (item-overview-tabs.tsx gates rendering by
 * item.type === "feature"). Submit / approve / request-changes / stale
 * reload / design-review scheduling all live here (contract-phase3.md's
 * Frontend Phase 3 doc-review-bar). */
export function DocTab({ workspaceId, item, doc, members }: DocTabProps) {
  const router = useRouter();
  const { atLeast } = useProjectRole();
  const [comment, setComment] = useState("");
  const [stale, setStale] = useState(false);
  const [pending, startTransition] = useTransition();

  function submit() {
    startTransition(async () => {
      const result = await submitDocAction(workspaceId, item.id);
      if (result.error) {
        toast.error(result.error);
        return;
      }
      toast.success("Spec submitted for review.");
      router.refresh();
    });
  }

  function review(verdict: ReviewVerdict) {
    if (verdict === "changes_requested" && comment.trim().length === 0) {
      toast.error("A comment is required when requesting changes.");
      return;
    }
    startTransition(async () => {
      const result = await reviewDocAction(workspaceId, item.id, {
        verdict,
        comment: comment.trim() || undefined,
        wiki_version: doc.page_version,
      });
      if (result.error) {
        if (result.error.toLowerCase().includes(STALE_MARKER)) setStale(true);
        else toast.error(result.error);
        return;
      }
      toast.success(verdict === "approved" ? "Approved." : "Changes requested.");
      setComment("");
      router.refresh();
    });
  }

  const pageHref = doc.space_slug && doc.page_slug ? ROUTES.wikiPage(doc.space_slug, doc.page_slug) : null;
  const canReview = doc.doc_status === "in_review";
  const canSubmit = doc.doc_status === null || doc.doc_status === "draft" || doc.doc_status === "changes_requested";

  return (
    <div className="flex flex-col gap-4">
      {stale && (
        <div className="flex flex-wrap items-center justify-between gap-2 rounded-md border border-warning/40 bg-warning/10 px-3 py-2 text-sm text-foreground">
          <span className="flex items-center gap-2">
            <AlertTriangle aria-hidden className="h-4 w-4 shrink-0" />
            The spec changed since you opened it — reload before reviewing.
          </span>
          <Button size="sm" variant="outline" onClick={() => { setStale(false); router.refresh(); }}>
            <RefreshCw aria-hidden className="mr-1.5 h-3.5 w-3.5" />
            Reload
          </Button>
        </div>
      )}

      {(item.spec_changed_at || doc.changed_since_approval) && (
        <div className="flex items-center gap-2 rounded-md border border-warning/40 bg-warning/10 px-3 py-2 text-sm text-foreground">
          <AlertTriangle aria-hidden className="h-4 w-4 shrink-0" />
          The requirement or spec page changed since this was approved — it needs review again.
        </div>
      )}

      <div className="card-base flex flex-col gap-3">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="flex min-w-0 items-center gap-2">
            {pageHref ? (
              <Link className="flex items-center gap-2 text-sm font-medium text-primary hover:underline" href={pageHref}>
                <FileText aria-hidden className="h-4 w-4 shrink-0" />
                Spec page (v{doc.page_version})
              </Link>
            ) : (
              <span className="text-sm text-muted-foreground">No spec page.</span>
            )}
            {doc.doc_status && <Badge variant="outline">{DOC_STATUS_LABEL[doc.doc_status]}</Badge>}
          </div>
          {atLeast("member") && canSubmit && (
            <Button disabled={pending} size="sm" onClick={submit}>
              {pending ? "Submitting…" : "Submit for review"}
            </Button>
          )}
        </div>

        <div className="flex flex-col gap-1">
          <p className="text-xs font-medium text-muted-foreground">Reviewers</p>
          {doc.reviewers.length === 0 ? (
            <p className="text-sm text-muted-foreground">None assigned.</p>
          ) : (
            <div className="flex flex-wrap gap-1.5">
              {doc.reviewers.map((r) => <Badge key={r.user_id} variant="secondary">{r.name}</Badge>)}
            </div>
          )}
        </div>

        {canReview && atLeast("member") && (
          <div className="flex flex-col gap-2 border-t border-border pt-3">
            <Textarea
              disabled={pending}
              placeholder="Comment (required to request changes)"
              rows={2}
              value={comment}
              onChange={(e) => setComment(e.target.value)}
            />
            <div className="flex flex-wrap gap-2">
              <Button disabled={pending} size="sm" onClick={() => review("approved")}>Approve</Button>
              <Button disabled={pending} size="sm" variant="outline" onClick={() => review("changes_requested")}>
                Request changes
              </Button>
            </div>
          </div>
        )}

        {doc.reviews.length > 0 && (
          <div className="flex flex-col gap-2 border-t border-border pt-3">
            <p className="text-xs font-medium text-muted-foreground">Review history</p>
            <ul className="flex flex-col gap-2">
              {doc.reviews.map((r) => (
                <li className="flex flex-col gap-0.5 text-sm" key={r.id}>
                  <div className="flex items-center justify-between gap-2">
                    <span className="font-medium">{r.reviewer_name}</span>
                    <Badge variant={REVIEW_VERDICT_VARIANT[r.verdict]}>{r.verdict.replace("_", " ")}</Badge>
                  </div>
                  {r.comment && <p className="text-muted-foreground">{r.comment}</p>}
                  <span className="text-xs text-muted-foreground">{new Date(r.created_at).toLocaleString()}</span>
                </li>
              ))}
            </ul>
          </div>
        )}
      </div>

      {atLeast("member") && (
        <ScheduleDesignReviewDialog
          itemId={item.id}
          itemTitle={item.title}
          members={members}
          reviewerIds={doc.reviewers.map((r) => r.user_id)}
          workspaceId={workspaceId}
        />
      )}
    </div>
  );
}
