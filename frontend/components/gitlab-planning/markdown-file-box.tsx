import { Copy, Download, FileText, Pencil, Trash2 } from "lucide-react";
import { cn } from "@/lib/utils";

import { Button } from "@/components/ui/button";
interface MarkdownFileBoxProps {
  name: string;
  markdown: string;
}

// Renders **bold** spans inside a line; the attached step notes are short
// Stitch-style outlines, not full markdown (the issue drawer uses react-markdown).
function inline(text: string) {
  return text.split(/(\*\*[^*]+\*\*)/g).map((part, i) =>
    part.startsWith("**") && part.endsWith("**")
      ? <span className="font-semibold" key={i}>{part.slice(2, -2)}</span>
      : part,
  );
}

const ACTIONS = [
  { label: "Edit", icon: Pencil },
  { label: "Copy", icon: Copy },
  { label: "Download", icon: Download },
];

export function MarkdownFileBox({ name, markdown }: MarkdownFileBoxProps) {
  const lines = markdown.split("\n");

  return (
    <div className="space-y-2 rounded-lg border border-border bg-accent/50 p-3">
      <div className="flex-between border-b border-border pb-1.5 text-xs">
        <div className="flex min-w-0 items-center gap-1.5 text-xs font-medium text-foreground">
          <FileText aria-hidden className="size-3.5 shrink-0 text-muted-foreground" />
          <span className="truncate">{name}</span>
        </div>
        <div className="flex items-center gap-1">
          <span className="rounded border border-border bg-card px-1.5 py-0.5 text-xs text-muted-foreground shadow-card">Preview</span>
          {ACTIONS.map(({ label, icon: Icon }) => (
            <Button aria-label={`${label} ${name}`} className="p-1 text-muted-foreground hover:text-muted-foreground" key={label} type="button" variant="unstyled">
              <Icon aria-hidden className="size-3.5" />
            </Button>
          ))}
          <Button aria-label={`Delete ${name}`} className="p-1 text-(--ae-danger-soft) hover:text-(--ae-danger)" type="button" variant="unstyled">
            <Trash2 aria-hidden className="size-3.5" />
          </Button>
        </div>
      </div>
      <div className="ae-mono space-y-1 rounded border border-border bg-card p-2 text-xs leading-relaxed text-foreground">
        {lines.map((line, i) => (
          <div
            className={cn(
              line.startsWith("# ") && "font-bold text-foreground",
              line.startsWith("## ") && "font-bold text-foreground",
              line.startsWith("## ") && i > 1 && "mt-1",
            )}
            key={i}
          >
            {inline(line)}
          </div>
        ))}
      </div>
    </div>
  );
}
