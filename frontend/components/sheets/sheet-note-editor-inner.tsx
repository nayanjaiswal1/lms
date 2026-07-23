"use client";

import { useRef, useState } from "react";
import { useEditor, EditorContent } from "@tiptap/react";
import type { JSONContent } from "@tiptap/react";
import StarterKit from "@tiptap/starter-kit";
import Placeholder from "@tiptap/extension-placeholder";
import { toast } from "sonner";
import { updateProgressNotesAction } from "@/lib/sheets/actions";
import { cn } from "@/lib/utils";
import styles from "@/components/shared/tiptap-editor.module.css";

const AUTOSAVE_DEBOUNCE_MS = 2000;

interface SheetNoteEditorInnerProps {
  topicTag: string;
  initialContent: JSONContent;
  editable: boolean;
}

type SaveStatus = "idle" | "saving" | "saved" | "error";

export function SheetNoteEditorInner({ topicTag, initialContent, editable }: SheetNoteEditorInnerProps) {
  const [status, setStatus] = useState<SaveStatus>("idle");
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  async function save(content: JSONContent) {
    setStatus("saving");
    const result = await updateProgressNotesAction(topicTag, content);
    setStatus(result.ok ? "saved" : "error");
    if (!result.ok) toast.error(result.error ?? "Couldn't save your note.");
  }

  function scheduleSave(content: JSONContent) {
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => void save(content), AUTOSAVE_DEBOUNCE_MS);
  }

  // editable is a reactive TipTap option — toggling the panel-wide edit
  // button flips this prop and re-renders the same editor instance in
  // place (no remount), same pattern as WikiEditorInner.
  const editor = useEditor({
    editable,
    immediatelyRender: false,
    extensions: [StarterKit, Placeholder.configure({ placeholder: "Write a note…" })],
    content: initialContent,
    onUpdate: ({ editor: e }) => scheduleSave(e.getJSON()),
  });

  if (!editor) {
    return <div className="skeleton h-16 w-full rounded-md" />;
  }

  if (!editable && editor.isEmpty) {
    return <p className="text-xs text-muted-foreground">No notes yet.</p>;
  }

  return (
    <div className="flex flex-col gap-1">
      <div className={cn(editable && "-mx-6 bg-muted/40 px-6 py-3")}>
        <div className={cn("prose-content", styles.content)}>
          <EditorContent editor={editor} />
        </div>
      </div>
      {editable && (
        <span aria-live="polite" className="h-4 text-xs text-muted-foreground">
          {status === "saving" && "Saving…"}
          {status === "saved" && "Saved"}
          {status === "error" && "Save failed"}
        </span>
      )}
    </div>
  );
}
