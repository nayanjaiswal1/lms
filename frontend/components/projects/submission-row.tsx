"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { ExternalLink, GitMerge, MessageSquare } from "lucide-react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { FormInputField } from "@/components/ui/form-input-field";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { CHECKPOINT_STATUS_LABEL, CHECKPOINT_STATUS_VARIANT, CI_STATUS_LABEL, CI_STATUS_VARIANT } from "@/lib/constants";
import { commentOnSubmissionAction, gradeSubmissionAction, mergeSubmissionAction } from "@/app/(app)/projects/actions";
import type { ProjectCheckpoint, ProjectTeamCheckpoint } from "@/lib/projects/types";

// Why the Merge button is disabled, mirroring Service.TryMergeCheckpoint's
// own gate (service_checkpoint.go) so the UI never offers a click the
// backend would reject anyway — checked in the same order the backend
// checks it (already merged/graded, no MR, approvals, CI).
function mergeBlockedReason(row: ProjectTeamCheckpoint, checkpoint: ProjectCheckpoint, requiredApprovals: number): string | null {
  if (row.status === "merged" || row.status === "graded") return "Already merged.";
  if (!row.mr_iid) return "No merge request submitted yet.";
  if (row.approvals_count < requiredApprovals) {
    const remaining = requiredApprovals - row.approvals_count;
    return `Needs ${remaining} more approval${remaining === 1 ? "" : "s"}.`;
  }
  if (checkpoint.requires_ci_pass && row.ci_status !== "success") return "Waiting for CI to pass.";
  return null;
}

const GradeSchema = z.object({
  score: z.string().refine((v) => v !== "" && Number(v) >= 0 && Number(v) <= 100, "Enter a score between 0 and 100."),
  feedback: z.string().optional(),
});
type GradeFormData = z.infer<typeof GradeSchema>;

interface SubmissionRowProps {
  submission: ProjectTeamCheckpoint;
  teamName: string;
  checkpoint: ProjectCheckpoint;
  assignmentId: string;
  requiredApprovals: number;
}

export function SubmissionRow({ submission, teamName, checkpoint, assignmentId, requiredApprovals }: SubmissionRowProps) {
  const router = useRouter();
  const [pending, setPending] = React.useState<null | "merge" | "comment">(null);
  const [commentBody, setCommentBody] = React.useState("");

  const gradeForm = useForm<GradeFormData>({
    resolver: zodResolver(GradeSchema),
    defaultValues: { score: submission.score !== null ? String(submission.score) : "", feedback: submission.feedback ?? "" },
  });

  const blockedReason = mergeBlockedReason(submission, checkpoint, requiredApprovals);
  const approvalsPct = Math.min(100, requiredApprovals > 0 ? (submission.approvals_count / requiredApprovals) * 100 : 0);

  async function handleMerge() {
    setPending("merge");
    const result = await mergeSubmissionAction(checkpoint.id, submission.team_id, assignmentId);
    setPending(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`${teamName}'s merge request was merged.`);
    router.refresh();
  }

  async function handleGrade(data: GradeFormData) {
    const result = await gradeSubmissionAction(checkpoint.id, submission.team_id, assignmentId, {
      score: Number(data.score),
      feedback: data.feedback?.trim() ? data.feedback.trim() : null,
    });
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success(`${teamName} graded.`);
    router.refresh();
  }

  async function handleComment() {
    if (!commentBody.trim()) return;
    setPending("comment");
    const result = await commentOnSubmissionAction(checkpoint.id, submission.team_id, assignmentId, commentBody.trim());
    setPending(null);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Comment posted to the merge request.");
    setCommentBody("");
  }

  return (
    <div className="flex flex-col gap-3 rounded-md border border-border p-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="text-sm font-semibold">{teamName}</span>
        <div className="flex flex-wrap items-center gap-1.5">
          <Badge variant={CHECKPOINT_STATUS_VARIANT[submission.status] ?? "outline"}>
            {CHECKPOINT_STATUS_LABEL[submission.status] ?? submission.status}
          </Badge>
          <Badge variant={CI_STATUS_VARIANT[submission.ci_status] ?? "outline"}>
            {CI_STATUS_LABEL[submission.ci_status] ?? submission.ci_status}
          </Badge>
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
        {submission.mr_web_url ? (
          <a className="inline-flex items-center gap-1 hover:underline" href={submission.mr_web_url} rel="noreferrer" target="_blank">
            Merge request ({submission.mr_state ?? "unknown"}) <ExternalLink aria-hidden className="h-3 w-3" />
          </a>
        ) : (
          <span>No merge request yet</span>
        )}
        <span>{submission.approvals_count}/{requiredApprovals} approvals</span>
        {submission.is_late && <span className="text-destructive">Late</span>}
      </div>

      <div className="progress-track border border-sidebar-border">
        {/* eslint-disable-next-line no-restricted-syntax -- dynamic progress width needs inline style */}
        <div className="progress-fill" style={{ width: `${approvalsPct}%` }} />
      </div>

      {submission.status === "graded" && (
        <p className="text-sm">
          <span className="font-semibold text-primary">{submission.score}/100</span>
          {submission.feedback && <span className="ml-2 text-muted-foreground">{submission.feedback}</span>}
        </p>
      )}

      <div className="flex flex-wrap items-center gap-2">
        <Button disabled={pending !== null || blockedReason !== null} size="sm" title={blockedReason ?? undefined} onClick={() => void handleMerge()}>
          <GitMerge aria-hidden className="mr-1.5 h-3.5 w-3.5" />
          {pending === "merge" ? "Merging…" : "Merge"}
        </Button>
        {blockedReason && <span className="text-xs text-muted-foreground">{blockedReason}</span>}

        <Dialog>
          <DialogTrigger asChild>
            <Button size="sm" variant="outline">
              {submission.status === "graded" ? "Re-grade" : "Grade"}
            </Button>
          </DialogTrigger>
          <DialogContent className="modal-responsive">
            <DialogHeader>
              <DialogTitle>Grade {teamName}</DialogTitle>
            </DialogHeader>
            <Form {...gradeForm}>
              <form className="form-stack" onSubmit={gradeForm.handleSubmit(handleGrade)}>
                <FormInputField control={gradeForm.control} label="Score (0–100)" name="score" type="number" />
                <FormField
                  control={gradeForm.control}
                  name="feedback"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Feedback (optional)</FormLabel>
                      <FormControl>
                        <Textarea placeholder="What went well, what to improve…" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <Button disabled={gradeForm.formState.isSubmitting} type="submit">
                  {gradeForm.formState.isSubmitting ? "Saving…" : "Save grade"}
                </Button>
              </form>
            </Form>
          </DialogContent>
        </Dialog>

        <Popover>
          <PopoverTrigger asChild>
            <Button size="sm" variant="ghost">
              <MessageSquare aria-hidden className="mr-1.5 h-3.5 w-3.5" />
              Comment
            </Button>
          </PopoverTrigger>
          <PopoverContent align="start">
            <div className="flex flex-col gap-2">
              <Textarea
                disabled={!submission.mr_iid}
                placeholder={submission.mr_iid ? "Post a comment on the merge request…" : "No merge request to comment on yet."}
                value={commentBody}
                onChange={(e) => setCommentBody(e.target.value)}
              />
              <Button
                disabled={pending !== null || !submission.mr_iid || !commentBody.trim()}
                size="sm"
                onClick={() => void handleComment()}
              >
                {pending === "comment" ? "Posting…" : "Post comment"}
              </Button>
            </div>
          </PopoverContent>
        </Popover>
      </div>
    </div>
  );
}
