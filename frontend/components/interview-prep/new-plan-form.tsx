"use client";

import { useActionState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { createPrepPlanAction } from "@/lib/interview-prep/actions";
import ROUTES from "@/lib/routes";

interface State { error?: string }

export function NewPlanForm() {
  const router = useRouter();

  const [state, formAction, pending] = useActionState(
    async (_prev: State | null, fd: globalThis.FormData): Promise<State | null> => {
      const jobTitle = (fd.get("job_title") as string).trim();
      if (!jobTitle) return { error: "Job title is required." };

      const result = await createPrepPlanAction({
        job_title: jobTitle,
        jd_text: (fd.get("jd_text") as string).trim() || undefined,
      });
      if (!result.ok || !result.data) return { error: result.error };
      router.push(ROUTES.interviewPrepPlan(result.data.id));
      return null;
    },
    null,
  );

  return (
    <form action={formAction} className="form-stack">
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="ip-title">Job title</Label>
        <Input
          required
          disabled={pending}
          id="ip-title"
          name="job_title"
          placeholder="e.g. Senior Backend Engineer"
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <Label htmlFor="ip-jd">Job description (optional)</Label>
        <Textarea
          className="resize-none text-sm"
          disabled={pending}
          id="ip-jd"
          name="jd_text"
          placeholder="Paste the full job description for a more tailored test…"
          rows={8}
        />
      </div>

      {state?.error && (
        <p className="rounded-md bg-destructive/10 p-3 text-sm text-destructive">{state.error}</p>
      )}

      <Button className="w-full sm:w-auto" disabled={pending} type="submit">
        {pending ? "Generating your mock test…" : "Generate prep plan"}
      </Button>
    </form>
  );
}
