"use client";

import dynamic from "next/dynamic";
import type { JSONContent } from "@tiptap/react";
import { Skeleton } from "@/components/ui/skeleton";

// TipTap is a heavy client-only dependency — dynamically imported per
// frontend/CLAUDE.md's "Heavy Dependencies" rule (same treatment as Monaco).
const WikiEditorInner = dynamic(
  () => import("@/components/wiki/wiki-editor-inner").then((m) => m.WikiEditorInner),
  { ssr: false, loading: () => <Skeleton className="h-64 w-full rounded-lg" /> },
);

interface WikiEditorProps {
  pageId: string;
  initialTitle: string;
  initialContent: JSONContent;
  editable: boolean;
}

export function WikiEditor(props: WikiEditorProps) {
  return <WikiEditorInner {...props} />;
}
