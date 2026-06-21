"use client";

import { useActionState, useState } from "react";
import { Sparkles } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Label } from "@/components/ui/label";
import { generateOutlineAction } from "@/lib/courses/actions";
import { COURSE_DIFFICULTY_OPTIONS, PRACTICE_QUESTION_COUNT_OPTIONS } from "@/lib/constants";

interface OutlineSection {
  title: string;
  modules: Array<{ title: string; type: string }>;
}

interface State {
  error?: string;
  outline?: OutlineSection[];
}

interface AIOutlinePanelProps {
  onApply?: (outline: OutlineSection[]) => void;
}

export function AIOutlinePanel({ onApply }: AIOutlinePanelProps) {
  const [moduleCount, setModuleCount] = useState("10");

  const [state, formAction, pending] = useActionState(
    async (_prev: State | null, fd: globalThis.FormData): Promise<State | null> => {
      const topic = (fd.get("topic") as string).trim();
      if (!topic) return { error: "Topic is required." };

      const result = await generateOutlineAction({
        topic,
        level: fd.get("level") as string,
        module_count: Number(fd.get("module_count")),
      });
      if (!result.ok) return { error: result.error };
      return { outline: result.data as OutlineSection[] };
    },
    null,
  );

  return (
    <div className="ai-surface flex flex-col gap-5 rounded-lg p-5">
      <div className="flex items-center gap-2">
        <Sparkles aria-hidden className="h-4 w-4 text-ai" />
        <span className="text-sm font-semibold text-ai">AI Course Outline</span>
      </div>

      <form action={formAction} className="flex flex-col gap-3">
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="ai-topic">Topic</Label>
          <Input required disabled={pending} id="ai-topic" name="topic" placeholder="e.g. Go concurrency patterns" />
        </div>

        <div className="grid-responsive-2 gap-3">
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="ai-level">Level</Label>
            <Select defaultValue="beginner" disabled={pending} name="level">
              <SelectTrigger aria-label="Difficulty level" id="ai-level">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {COURSE_DIFFICULTY_OPTIONS.map((o) => (
                  <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="flex flex-col gap-1.5">
            <Label htmlFor="ai-modules">Modules</Label>
            <Select defaultValue={moduleCount} disabled={pending} name="module_count" onValueChange={setModuleCount}>
              <SelectTrigger aria-label="Number of modules" id="ai-modules">
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

        {state?.error && <p className="text-sm text-destructive">{state.error}</p>}

        <Button className="border-ai text-ai" disabled={pending} type="submit" variant="outline">
          <Sparkles aria-hidden className="mr-2 h-3.5 w-3.5" />
          {pending ? "Generating…" : "Generate outline"}
        </Button>
      </form>

      {state?.outline && state.outline.length > 0 && (
        <div className="flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <h4 className="text-sm font-semibold">Generated outline</h4>
            {onApply && state.outline && (
              <Button size="sm" onClick={() => onApply(state.outline as OutlineSection[])}>
                Apply to course
              </Button>
            )}
          </div>
          <ol className="flex flex-col gap-2">
            {state.outline.map((section, si) => (
              <li className="rounded-md border border-border p-3" key={si}>
                <p className="text-sm font-medium">{section.title}</p>
                {section.modules?.length > 0 && (
                  <ul className="mt-1.5 flex flex-col gap-0.5 pl-3">
                    {section.modules.map((mod, mi) => (
                      <li className="text-xs text-muted-foreground" key={mi}>
                        {mod.title}
                      </li>
                    ))}
                  </ul>
                )}
              </li>
            ))}
          </ol>
        </div>
      )}
    </div>
  );
}
