"use client";

import { useRef, useState } from "react";
import { useEditor, EditorContent } from "@tiptap/react";
import type { JSONContent } from "@tiptap/react";
import StarterKit from "@tiptap/starter-kit";
import Underline from "@tiptap/extension-underline";
import { Table } from "@tiptap/extension-table";
import TableRow from "@tiptap/extension-table-row";
import TableCell from "@tiptap/extension-table-cell";
import TableHeader from "@tiptap/extension-table-header";
import TaskList from "@tiptap/extension-task-list";
import TaskItem from "@tiptap/extension-task-item";
import TiptapImage from "@tiptap/extension-image";
import TiptapLink from "@tiptap/extension-link";
import Placeholder from "@tiptap/extension-placeholder";
import CodeBlockLowlight from "@tiptap/extension-code-block-lowlight";
import { createLowlight, common } from "lowlight";
import { toast } from "sonner";
import { WikiEditorToolbar } from "@/components/wiki/wiki-editor-toolbar";
import { updatePageAction } from "@/lib/wiki/actions";
import { cn } from "@/lib/utils";
import styles from "@/components/shared/tiptap-editor.module.css";

const lowlight = createLowlight(common);
const AUTOSAVE_DEBOUNCE_MS = 2000;

interface WikiEditorInnerProps {
  pageId: string;
  initialTitle: string;
  initialContent: JSONContent;
  editable: boolean;
}

type SaveStatus = "idle" | "saving" | "saved" | "error";

export function WikiEditorInner({ pageId, initialTitle, initialContent, editable }: WikiEditorInnerProps) {
  const [title, setTitle] = useState(initialTitle);
  const [status, setStatus] = useState<SaveStatus>("idle");
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  async function save(nextTitle: string, content: JSONContent) {
    setStatus("saving");
    const result = await updatePageAction(pageId, { title: nextTitle, content });
    setStatus(result.ok ? "saved" : "error");
    if (!result.ok) toast.error(result.error ?? "Couldn't save your changes.");
  }

  function scheduleSave(nextTitle: string, content: JSONContent) {
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => void save(nextTitle, content), AUTOSAVE_DEBOUNCE_MS);
  }

  const editor = useEditor({
    editable,
    immediatelyRender: false,
    extensions: [
      StarterKit.configure({ codeBlock: false }),
      Underline,
      Table.configure({ resizable: true }),
      TableRow,
      TableHeader,
      TableCell,
      TaskList,
      TaskItem.configure({ nested: true }),
      TiptapImage,
      TiptapLink.configure({ openOnClick: !editable, autolink: true }),
      Placeholder.configure({ placeholder: "Write something…" }),
      CodeBlockLowlight.configure({ lowlight }),
    ],
    content: initialContent,
    onUpdate: editable ? ({ editor: e }) => scheduleSave(title, e.getJSON()) : undefined,
  });

  function handleTitleChange(e: React.ChangeEvent<HTMLInputElement>) {
    const next = e.target.value;
    setTitle(next);
    if (editor) scheduleSave(next, editor.getJSON());
  }

  if (!editor) {
    return <div className="skeleton h-64 w-full" />;
  }

  return (
    <div className="flex flex-col gap-3">
      {editable ? (
        <div className="flex items-center justify-between gap-3">
          <input
            aria-label="Page title"
            className="w-full border-none bg-transparent text-3xl font-bold tracking-tight text-foreground outline-none placeholder:text-muted-foreground"
            placeholder="Untitled"
            value={title}
            onChange={handleTitleChange}
          />
          <span aria-live="polite" className="shrink-0 text-xs text-muted-foreground">
            {status === "saving" && "Saving…"}
            {status === "saved" && "Saved"}
            {status === "error" && "Save failed"}
          </span>
        </div>
      ) : (
        <h1>{title}</h1>
      )}

      <div className={cn("rounded-lg", editable && "border border-border bg-card")}>
        {editable && <WikiEditorToolbar editor={editor} />}
        <div className={cn("prose-content", editable && "p-4", styles.content)}>
          <EditorContent editor={editor} />
        </div>
      </div>
    </div>
  );
}
