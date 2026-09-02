"use client";

import { useState } from "react";
import { CheckCircle2 } from "lucide-react";
import { toast } from "sonner";
import { setAnonReflection } from "@/lib/courses/anon-progress";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";

interface AnonLessonReflectionProps {
  courseId: string;
  moduleId: string;
  initialResponse: string | null;
  /** Reports the saved text up to AnonLessonPage, which gates AnonModuleCompleteButton on it. */
  onSaved?: (response: string) => void;
}

// Anonymous counterpart to lesson-reflection.tsx — same box, saved to
// localStorage instead of the server. Migrated into the real
// lesson_reflections row on login (see anon-progress-migrator.tsx).
export function AnonLessonReflection({ courseId, moduleId, initialResponse, onSaved }: AnonLessonReflectionProps) {
  const [response, setResponse] = useState(initialResponse ?? "");
  const [saved, setSaved] = useState(Boolean(initialResponse));

  function submit() {
    const trimmed = response.trim();
    if (!trimmed) {
      toast.error("Write a few sentences about what you understood first.");
      return;
    }
    setAnonReflection(courseId, moduleId, trimmed);
    setSaved(true);
    onSaved?.(trimmed);
    toast.success("Reflection saved to this browser.");
  }

  return (
    <div className="flex flex-col gap-3 rounded-lg border border-primary/40 bg-card p-4">
      <div>
        <span className="text-xs font-semibold text-primary">Reflect</span>
        <p className="mt-1 text-sm text-muted-foreground">
          In your own words: what did you understand from this lesson? Saved in this browser only —
          sign in to keep it permanently.
        </p>
      </div>

      <Textarea
        className="min-h-28"
        placeholder="I learned that..."
        value={response}
        onChange={(e) => {
          setResponse(e.target.value);
          setSaved(false);
        }}
      />

      <Button className="w-fit" disabled={!response.trim()} size="sm" onClick={submit}>
        {saved ? (
          <>
            <CheckCircle2 aria-hidden className="mr-1 h-3.5 w-3.5" />
            Saved — edit anytime
          </>
        ) : (
          "Save reflection"
        )}
      </Button>
    </div>
  );
}
