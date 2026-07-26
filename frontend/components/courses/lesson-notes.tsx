"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";
import { NotebookPen, Loader2, CheckCircle2 } from "lucide-react";
import { saveLessonNoteAction } from "@/lib/courses/actions";
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";

interface LessonNotesProps {
  moduleId: string;
  initialContent: string | null;
}

// A student's personal, editable overlay on a lesson — separate from the
// lesson content itself (always visible on the page behind this sheet) and
// separate from the ungraded "Reflect" box (lesson-reflection.tsx), which
// captures a one-time understanding signal rather than ongoing notes.
// "View original" is simply closing this sheet — the note never replaces
// or hides the underlying lesson content, only sits alongside it. The same
// content this panel edits can also be written by the student's connected
// AI client via the save_my_lesson_note MCP tool (see mcpconnect docs).
export function LessonNotes({ moduleId, initialContent }: LessonNotesProps) {
  const [content, setContent] = useState(initialContent ?? "");
  const [saved, setSaved] = useState(Boolean(initialContent));
  const [isPending, startTransition] = useTransition();

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
    <Sheet>
      <SheetTrigger asChild>
        <Button size="sm" variant="outline">
          <NotebookPen aria-hidden className="mr-2 h-4 w-4" />
          My notes
        </Button>
      </SheetTrigger>
      <SheetContent className="modal-responsive flex flex-col gap-4">
        <SheetHeader>
          <SheetTitle>My notes</SheetTitle>
        </SheetHeader>
        <p className="text-sm text-muted-foreground">
          Your own notes for this lesson — separate from the lesson content itself. Close this
          panel any time to see the original lesson again.
        </p>
        <Textarea
          className="min-h-64 flex-1"
          onChange={(e) => {
            setContent(e.target.value);
            setSaved(false);
          }}
          placeholder="Write anything you want to remember about this lesson..."
          value={content}
        />
        <Button className="w-fit self-end" disabled={isPending || !content.trim()} onClick={save} size="sm">
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
      </SheetContent>
    </Sheet>
  );
}
