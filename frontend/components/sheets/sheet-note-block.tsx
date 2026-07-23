import type { JSONContent } from "@tiptap/react";
import { SheetNoteEditor } from "@/components/sheets/sheet-note-editor";
import type { SheetItem } from "@/lib/server/sheets";
import { cn } from "@/lib/utils";

const EMPTY_DOC: JSONContent = { type: "doc", content: [{ type: "paragraph" }] };

export function noteBlockId(itemId: string): string {
  return `sheet-note-${itemId}`;
}

function hasContent(notes: JSONContent): boolean {
  return Array.isArray(notes.content) && notes.content.length > 0;
}

interface SheetNoteBlockProps {
  item: SheetItem;
  isActive: boolean;
  isMounted: boolean;
  editable: boolean;
}

export function SheetNoteBlock({ item, isActive, isMounted, editable }: SheetNoteBlockProps) {
  const isEmpty = !hasContent(item.notes);
  return (
    <section
      className={cn(
        "scroll-mt-20 rounded-md transition-colors duration-normal",
        isEmpty && !editable ? "px-6 py-3" : "p-6",
        isActive && "ring-1 ring-inset ring-primary bg-primary/5",
      )}
      id={noteBlockId(item.id)}
    >
      {isMounted ? (
        <SheetNoteEditor
          editable={editable}
          initialContent={hasContent(item.notes) ? item.notes : EMPTY_DOC}
          topicTag={item.topic_tag}
        />
      ) : (
        // Matches the eventual real height for the common empty case so
        // lazy-mounting the editor doesn't reflow content out from under an
        // in-progress scroll — a skeleton taller than its real content shrinks
        // on mount and shifts every block below it.
        <div className={cn("skeleton w-full rounded-md", isEmpty && !editable ? "h-4" : "h-16")} />
      )}
    </section>
  );
}
