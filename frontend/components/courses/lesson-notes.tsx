"use client";

import { useState, useTransition } from "react";
import { useQueryState } from "nuqs";
import { toast } from "sonner";
import { NotebookPen, Loader2, CheckCircle2 } from "lucide-react";
import { saveLessonNoteAction } from "@/lib/courses/actions";
import { LessonFloatingPanel } from "@/components/shared/lesson-floating-panel";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";

interface LessonNotesProps {
  moduleId: string;
  initialContent: string | null;
}

// A student's personal, editable overlay on a lesson — separate from the
// lesson content itself (always visible on the page behind this panel) and
// separate from the ungraded "Reflect" box (lesson-reflection.tsx), which
// captures a one-time understanding signal rather than ongoing notes.
// Closing this panel never replaces or hides the underlying lesson content,
// only sits alongside it. The same content this panel edits can also be
// written by the student's connected AI client via the save_my_lesson_note
// MCP tool (see mcpconnect docs).
export function LessonNotes({ moduleId, initialContent }: LessonNotesProps) {
  const [content, setContent] = useState(initialContent ?? "");
  const [saved, setSaved] = useState(Boolean(initialContent));
  const [isPending, startTransition] = useTransition();
  // Shared with HighlightProvider — only one lesson overlay (notes or
  // highlight explain) may be open at a time.
  const [lessonPanel, setLessonPanel] = useQueryState("lessonPanel");

  function save() {
    const trimmed = content.trim();
    if (!trimmed) {
      toast.error("Write something before saving.");
      return;
    }
    startTransition(async () => {
      const result = await saveLessonNoteAction({ moduleID: moduleId, content: trimmed });
      if (result.ok) {
        setSaved(true);
        toast.success("Note saved.");
      } else {
        toast.error(result.error ?? "Couldn't save your note — try again.");
      }
    });
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
            <Textarea
              className="min-h-40 flex-1"
              placeholder="Write anything you want to remember about this lesson..."
              value={content}
              onChange={(e) => {
                setContent(e.target.value);
                setSaved(false);
              }}
            />
            <Button className="w-fit self-end" disabled={isPending || !content.trim()} size="sm" onClick={save}>
              {isPending ? (
                <Loader2 aria-hidden className="h-3.5 w-3.5 animate-spin" />
              ) : saved ? (
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
