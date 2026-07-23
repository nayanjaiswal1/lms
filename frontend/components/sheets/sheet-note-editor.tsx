"use client";

import dynamic from "next/dynamic";
import type { JSONContent } from "@tiptap/react";
import { Skeleton } from "@/components/ui/skeleton";

// TipTap is a heavy client-only dependency — dynamically imported per
// frontend/CLAUDE.md's "Heavy Dependencies" rule (same treatment as Monaco).
const SheetNoteEditorInner = dynamic(
  () => import("@/components/sheets/sheet-note-editor-inner").then((m) => m.SheetNoteEditorInner),
  { ssr: false, loading: () => <Skeleton className="h-16 w-full rounded-md" /> },
);

interface SheetNoteEditorProps {
  topicTag: string;
  initialContent: JSONContent;
  editable: boolean;
}

export function SheetNoteEditor(props: SheetNoteEditorProps) {
  return <SheetNoteEditorInner {...props} />;
}
