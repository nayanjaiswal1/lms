"use client";

import { useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { upsertCertificateRuleAction } from "@/lib/courses/actions";
import type { CertificateRule } from "@/lib/server/courses";

interface CertificateRuleFormProps {
  courseId: string;
  initial: CertificateRule | null;
}

// Threshold-based auto-issue is optional and independent of the final test
// above — a course can award a certificate purely from completion percent
// (paid courses additionally require a completed purchase, checked
// server-side). Owns its own save button, same as FinalTestTab, since it's
// a separate PUT saved independently of the rest of the wizard.
export function CertificateRuleForm({ courseId, initial }: CertificateRuleFormProps) {
  const [threshold, setThreshold] = useState(initial?.threshold_percent ?? 100);
  const [pending, setPending] = useState(false);

  async function handleSave() {
    setPending(true);
    const res = await upsertCertificateRuleAction(courseId, threshold);
    setPending(false);
    if (!res.ok) {
      toast.error(res.error ?? "Failed to save certificate rule.");
      return;
    }
    toast.success("Certificate threshold saved.");
  }

  return (
    <div className="card-base flex flex-col gap-3 p-4">
      <div className="flex flex-col gap-1">
        <p className="font-medium">Auto-issue by completion</p>
        <p className="text-sm text-muted-foreground">
          Award a certificate once a learner reaches this percent complete — no final test
          required. Paid courses also require a completed purchase.
        </p>
      </div>
      <div className="flex items-end gap-3">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="certificate-threshold">Completion threshold (%)</Label>
          <Input
            className="w-32"
            id="certificate-threshold"
            max={100}
            min={1}
            type="number"
            value={threshold}
            onChange={(e) => setThreshold(Number(e.target.value))}
          />
        </div>
        <Button disabled={pending} type="button" onClick={handleSave}>
          {pending ? "Saving…" : "Save threshold"}
        </Button>
      </div>
    </div>
  );
}
