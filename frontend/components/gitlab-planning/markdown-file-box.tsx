import { Copy, Download, FileText, Pencil, Trash2 } from "lucide-react";
import { cn } from "@/lib/utils";

interface MarkdownFileBoxProps {
  name: string;
  markdown: string;
}

// Renders **bold** spans inside a line; the attached step notes are short
// Stitch-style outlines, not full markdown (the issue drawer uses react-markdown).
function inline(text: string) {
  return text.split(/(\*\*[^*]+\*\*)/g).map((part, i) =>
    part.startsWith("**") && part.endsWith("**")
      ? <span key={i} className="font-semibold">{part.slice(2, -2)}</span>
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
    <div className="space-y-2 rounded-lg border border-(--ae-line) bg-(--ae-hover)/50 p-3">
      <div className="flex items-center justify-between border-b border-(--ae-line) pb-1.5 text-xs">
        <div className="flex min-w-0 items-center gap-1.5 text-[11px] font-medium text-(--ae-body)">
          <FileText className="size-3.5 shrink-0 text-(--ae-faint)" aria-hidden />
          <span className="truncate">{name}</span>
        </div>
        <div className="flex items-center gap-1">
          <span className="rounded border border-(--ae-line) bg-(--ae-card) px-1.5 py-0.5 text-[10px] text-(--ae-muted) shadow-2xs">Preview</span>
          {ACTIONS.map(({ label, icon: Icon }) => (
            <button key={label} type="button" aria-label={`${label} ${name}`} className="p-1 text-(--ae-faint) hover:text-(--ae-dim)">
              <Icon className="size-3.5" aria-hidden />
            </button>
          ))}
          <button type="button" aria-label={`Delete ${name}`} className="p-1 text-(--ae-danger-soft) hover:text-(--ae-danger)">
            <Trash2 className="size-3.5" aria-hidden />
          </button>
        </div>
      </div>
      <div className="ae-mono space-y-1 rounded border border-(--ae-soft) bg-(--ae-card) p-2 text-[11px] leading-relaxed text-(--ae-body)">
        {lines.map((line, i) => (
          <div
            key={i}
            className={cn(
              line.startsWith("# ") && "font-bold text-(--ae-ink)",
              line.startsWith("## ") && "font-bold text-(--ae-text)",
              line.startsWith("## ") && i > 1 && "mt-1",
            )}
          >
            {inline(line)}
          </div>
        ))}
      </div>
    </div>
  );
}
