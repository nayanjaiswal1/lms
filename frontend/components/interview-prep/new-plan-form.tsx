"use client";

import { useState } from "react";
import { useActionState } from "react";
import { useRouter } from "next/navigation";
import { parseAsStringEnum, useQueryState } from "nuqs";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from "@/components/ui/accordion";
import { createPrepPlanAction } from "@/lib/interview-prep/actions";
import { classifyPrepInput, type PrepMode } from "@/lib/interview-prep/classify";
import { PRACTICE_CATEGORY_OPTIONS, PRACTICE_DIFFICULTY_OPTIONS, PRACTICE_QUESTION_COUNT_OPTIONS } from "@/lib/constants";
import ROUTES from "@/lib/routes";

interface State { error?: string }

const MODE_LABEL: Record<PrepMode, string> = {
  quick: "Quick Practice",
  targeted: "Job-Targeted Mock Test",
};
const OTHER_MODE: Record<PrepMode, PrepMode> = { quick: "targeted", targeted: "quick" };

// One field replaces the old two-form toggle: quick vs targeted is
// auto-classified from what the user typed (see lib/interview-prep/classify),
// with a one-click override if the guess is wrong. Advanced options only
// apply to quick mode — targeted mode's difficulty/skills come from AI
// extraction on the pasted text, not a manual picker.
export function NewPlanForm() {
  const router = useRouter();
  const [text, setText] = useState("");
  const [modeOverride, setModeOverride] = useQueryState("mode", parseAsStringEnum<PrepMode>(["quick", "targeted"]));
  const [advancedOpen, setAdvancedOpen] = useQueryState("advanced", parseAsStringEnum<"open">(["open"]));

  const mode = modeOverride ?? classifyPrepInput(text);

  const [state, formAction, pending] = useActionState(
    async (_prev: State | null, fd: globalThis.FormData): Promise<State | null> => {
      const value = (fd.get("text") as string).trim();
      if (!value) return { error: "Tell us what you're preparing for." };

      const result = await createPrepPlanAction({
        text: value,
        modeOverride: modeOverride ?? undefined,
        difficulty: fd.get("difficulty") as string,
        questionCount: fd.get("question_count") ? Number(fd.get("question_count")) : undefined,
        category: (fd.get("category") as "technical" | "behavioral") || undefined,
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
        <Label htmlFor="ip-text">What are you preparing for?</Label>
        <Textarea
          className="resize-none text-sm"
          disabled={pending}
          id="ip-text"
          name="text"
          placeholder={'e.g. "Go interview practice" — or paste a full job description for Senior Backend Engineer…'}
          rows={6}
          value={text}
          onChange={(e) => setText(e.target.value)}
        />
        {text.trim() && (
          <p className="text-xs text-muted-foreground">
            We&apos;ll set this up as <span className="font-medium text-foreground">{MODE_LABEL[mode]}</span>
            {" — "}
            <button
              className="text-primary underline-offset-2 hover:underline"
              type="button"
              onClick={() => setModeOverride(OTHER_MODE[mode])}
            >
              switch to {MODE_LABEL[OTHER_MODE[mode]]}
            </button>
          </p>
        )}
      </div>

      {mode === "quick" && (
        <Accordion
          collapsible
          type="single"
          value={advancedOpen ? "advanced" : ""}
          onValueChange={(v) => setAdvancedOpen(v === "advanced" ? "open" : null)}
        >
          <AccordionItem value="advanced">
            <AccordionTrigger>Advanced</AccordionTrigger>
            <AccordionContent>
              <div className="grid-responsive-2 gap-4 pt-1">
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="ip-category">Category</Label>
                  <Select defaultValue="technical" disabled={pending} name="category">
                    <SelectTrigger aria-label="Category" id="ip-category">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {PRACTICE_CATEGORY_OPTIONS.map((o) => (
                        <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="flex flex-col gap-1.5">
                  <Label htmlFor="ip-diff">Difficulty</Label>
                  <Select defaultValue="intermediate" disabled={pending} name="difficulty">
                    <SelectTrigger aria-label="Difficulty" id="ip-diff">
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
                  <Label htmlFor="ip-count">Number of questions</Label>
                  <Select defaultValue="5" disabled={pending} name="question_count">
                    <SelectTrigger aria-label="Question count" id="ip-count">
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
            </AccordionContent>
          </AccordionItem>
        </Accordion>
      )}

      {state?.error && (
        <p className="rounded-md bg-destructive/10 p-3 text-sm text-destructive">{state.error}</p>
      )}

      <Button className="w-full sm:w-auto" disabled={pending} type="submit">
        {pending ? "Generating…" : mode === "quick" ? "Start session" : "Generate prep plan"}
      </Button>
    </form>
  );
}
