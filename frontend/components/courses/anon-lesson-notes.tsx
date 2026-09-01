"use client";

import { useState } from "react";
import { useQueryState } from "nuqs";
import { toast } from "sonner";
import { NotebookPen, CheckCircle2 } from "lucide-react";
import { setAnonNote } from "@/lib/courses/anon-progress";
import { LessonFloatingPanel } from "@/components/shared/lesson-floating-panel";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";

interface AnonLessonNotesProps {
  courseId: string;
  moduleId: string;
  initialContent: string | null;
}

// Anonymous counterpart to lesson-notes.tsx — same floating panel, saved to
// localStorage instead of via saveLessonNoteAction. Migrated into a real
// lesson note on login (see anon-progress-migrator.tsx).
export function AnonLessonNotes({ courseId, moduleId, initialContent }: AnonLessonNotesProps) {
  const [content, setContent] = useState(initialContent ?? "");
  const [saved, setSaved] = useState(Boolean(initialContent));
  const [lessonPanel, setLessonPanel] = useQueryState("lessonPanel");

  function save() {
    const trimmed = content.trim();
    if (!trimmed) {
      toast.error("Write something before saving.");
      return;
    }
    setAnonNote(courseId, moduleId, trimmed);
    setSaved(true);
    toast.success("Note saved to this browser.");
  }

  return (
    <>
      <Button className="w-full" size="sm" variant="secondary" onClick={() => setLessonPanel("notes")}>
        <NotebookPen aria-hidden className="mr-2 h-4 w-4" />
        My notes
      </Button>

      {lessonPanel === "notes" && (
        <LessonFloatingPanel
          ariaLabel="My notes"
          icon={<NotebookPen aria-hidden className="size-4 text-muted-foreground" />}
          title="My notes"
          onClose={() => setLessonPanel(null)}
        >
          <div className="min-h-0 flex-1 overflow-y-auto flex flex-col gap-3 p-4">
            <p className="text-xs text-muted-foreground">Saved in this browser only — sign in to keep it permanently.</p>
            <Textarea
              className="min-h-40 flex-1"
              placeholder="Write anything you want to remember about this lesson..."
              value={content}
              onChange={(e) => {
                setContent(e.target.value);
                setSaved(false);
              }}
            />
            <Button className="w-fit self-end" disabled={!content.trim()} size="sm" onClick={save}>
              {saved ? (
                <>
                  <CheckCircle2 aria-hidden className="mr-1 h-3.5 w-3.5" />
                  Saved — edit anytime
                </>
              ) : (
                "Save note"
              )}
            </Button>
          </div>
        </LessonFloatingPanel>
      )}
    </>
  );
}
