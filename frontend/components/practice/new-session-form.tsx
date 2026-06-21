"use client";

import { useActionState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Label } from "@/components/ui/label";
import { createSessionAction } from "@/lib/practice/actions";
import {
  PRACTICE_DIFFICULTY_OPTIONS,
  PRACTICE_QUESTION_COUNT_OPTIONS,
  PRACTICE_TECHNOLOGY_OPTIONS,
} from "@/lib/constants";
import ROUTES from "@/lib/routes";

interface State { error?: string }

export function NewSessionForm() {
  const router = useRouter();

  const [state, formAction, pending] = useActionState(
    async (_prev: State | null, fd: globalThis.FormData): Promise<State | null> => {
      const result = await createSessionAction({
        technology: fd.get("technology") as string,
        difficulty: fd.get("difficulty") as string,
        question_count: Number(fd.get("question_count")),
      });
      if (!result.ok) return { error: result.error };
      router.push(`${ROUTES.practiceSession(result.data!.id)}?q=0`);
      return null;
    },
    null,
  );

  return (
    <form action={formAction} className="form-stack">
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="ps-tech">Technology</Label>
        <Select name="technology" defaultValue="Go" disabled={pending}>
          <SelectTrigger id="ps-tech" aria-label="Technology">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {PRACTICE_TECHNOLOGY_OPTIONS.map((o) => (
              <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <div className="grid-responsive-2 gap-4">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="ps-diff">Difficulty</Label>
          <Select name="difficulty" defaultValue="intermediate" disabled={pending}>
            <SelectTrigger id="ps-diff" aria-label="Difficulty">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {PRACTICE_DIFFICULTY_OPTIONS.map((o) => (
                <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <div className="flex flex-col gap-1.5">
          <Label htmlFor="ps-count">Number of questions</Label>
          <Select name="question_count" defaultValue="5" disabled={pending}>
            <SelectTrigger id="ps-count" aria-label="Question count">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {PRACTICE_QUESTION_COUNT_OPTIONS.map((o) => (
                <SelectItem key={o.value} value={String(o.value)}>{o.label}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>

      {state?.error && (
        <p className="rounded-md bg-destructive/10 p-3 text-sm text-destructive">{state.error}</p>
      )}

      <Button type="submit" disabled={pending} className="w-full sm:w-auto">
        {pending ? "Generating questions…" : "Start session"}
      </Button>
    </form>
  );
}
