"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { applyToRequirementAction, withdrawApplicationAction } from "@/app/(app)/projects/actions";
import { APPLICATION_STATUS_LABEL, APPLICATION_STATUS_VARIANT } from "@/lib/constants";
import type { ProjectApplication } from "@/lib/projects/types";

interface ApplyPanelProps {
  requirementId: string;
  isOpen: boolean;
  myApplication: ProjectApplication | null;
}

export function ApplyPanel({ requirementId, isOpen, myApplication }: ApplyPanelProps) {
  const router = useRouter();
  const [motivation, setMotivation] = React.useState("");
  const [resumeText, setResumeText] = React.useState("");
  const [pending, setPending] = React.useState(false);

  async function handleApply() {
    setPending(true);
    const result = await applyToRequirementAction(requirementId, motivation.trim(), resumeText.trim());
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Application submitted.");
    router.refresh();
  }

  async function handleWithdraw() {
    if (!myApplication) return;
    setPending(true);
    const result = await withdrawApplicationAction(myApplication.id, requirementId);
    setPending(false);
    if (result.error) {
      toast.error(result.error);
      return;
    }
    toast.success("Application withdrawn.");
    router.refresh();
  }

  if (myApplication) {
    return (
      <div className="card-base flex flex-col gap-3 p-6">
        <div className="flex items-center gap-2">
          <span className="font-medium">Your application</span>
          <Badge variant={APPLICATION_STATUS_VARIANT[myApplication.status] ?? "outline"}>
            {APPLICATION_STATUS_LABEL[myApplication.status] ?? myApplication.status}
          </Badge>
        </div>
        {myApplication.motivation && <p className="text-sm text-muted-foreground">{myApplication.motivation}</p>}
        {myApplication.status === "submitted" && (
          <Button className="self-start" disabled={pending} variant="outline" onClick={handleWithdraw}>
            {pending ? "Withdrawing…" : "Withdraw application"}
          </Button>
        )}
      </div>
    );
  }

  if (!isOpen) {
    return (
      <div className="empty-state py-8">
        <p className="text-sm text-muted-foreground">This requirement isn&apos;t accepting applications.</p>
      </div>
    );
  }

  return (
    <div className="card-base flex flex-col gap-4 p-6">
      <span className="font-medium">Apply</span>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="apply-motivation">Why you&apos;re a good fit</Label>
        <Textarea
          id="apply-motivation"
          placeholder="What draws you to this project, and relevant experience…"
          rows={4}
          value={motivation}
          onChange={(e) => setMotivation(e.target.value)}
        />
      </div>
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="apply-resume">Resume (optional)</Label>
        <Textarea
          id="apply-resume"
          placeholder="Paste your resume text — used alongside your GitHub profile for AI-assisted shortlisting."
          rows={6}
          value={resumeText}
          onChange={(e) => setResumeText(e.target.value)}
        />
      </div>
      <Button className="self-end" disabled={pending} onClick={handleApply}>
        {pending ? "Submitting…" : "Submit application"}
      </Button>
    </div>
  );
}
