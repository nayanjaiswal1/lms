"use client";

import { useActionState } from "react";
import { useRouter } from "next/navigation";
import { RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { createPrepPlanAction } from "@/lib/interview-prep/actions";
import ROUTES from "@/lib/routes";

interface PracticeAgainButtonProps {
  jobTitle: string;
  weakSkills: string[];
}

interface State { error?: string }

export function PracticeAgainButton({ jobTitle, weakSkills }: PracticeAgainButtonProps) {
  const router = useRouter();

  const [state, formAction, pending] = useActionState(
    async (_prev: State | null): Promise<State | null> => {
      const result = await createPrepPlanAction({
        text:
          jobTitle +
          (weakSkills.length > 0 ? `\n\nFocus specifically on: ${weakSkills.join(", ")}` : ""),
        // Force targeted — a short job title alone could otherwise misclassify
        // as quick, and "practice again" must always regenerate a full mock test.
        modeOverride: "targeted",
      });
      if (!result.ok || !result.data) return { error: result.error };
      router.push(ROUTES.interviewPrepPlan(result.data.id));
      return null;
    },
    null,
  );

  return (
    <div className="flex flex-col gap-2">
      <Button disabled={pending} variant="outline" onClick={() => formAction()}>
        <RefreshCw aria-hidden className="mr-2 h-4 w-4" />
        {pending ? "Generating…" : "Practice weak areas again"}
      </Button>
      {state?.error && <p className="text-sm text-destructive">{state.error}</p>}
    </div>
  );
}
