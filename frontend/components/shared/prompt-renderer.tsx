import { cn } from "@/lib/utils";

interface PromptRendererProps {
  text: string;
  textClassName?: string;
}

// Parses a prompt string and renders fenced code blocks (```lang\n…```) as
// <pre><code>, inline `backtick` spans as <code>, and **bold** spans as
// <strong>. Falls back to plain paragraphs when no markers are present, so
// prompts without any markup are unaffected. Shared by assessment (MCQ,
// subjective, coding) and course final-test question prompts so every
// surface renders the same lightweight markup consistently instead of
// leaking raw ``` and ** characters into the UI.
export function PromptRenderer({ text, textClassName }: PromptRendererProps) {
  const segments = text.split(/(```[\w]*\n[\s\S]*?```)/g).filter(Boolean);
  const hasBlocks = segments.some((s) => s.startsWith("```"));

  const nodes = segments.map((seg, i) => {
    const blockMatch = seg.match(/^```(\w*)\n([\s\S]*?)```$/);
    if (blockMatch) {
      const code = blockMatch[2].replace(/\n$/, "");
      return (
        <pre
          key={i}
          className="overflow-x-auto rounded-[--radius-md] border border-border bg-muted p-4 font-mono text-sm leading-relaxed"
        >
          <code>{code}</code>
        </pre>
      );
    }

    const trimmed = seg.replace(/^\n+|\n+$/g, "");
    if (!trimmed) return null;

    // Render inline `code` spans and **bold** spans within text segments
    const parts = trimmed.split(/(`[^`\n]+`|\*\*[^*\n]+\*\*)/g);
    const inline = parts.map((chunk, j) => {
      if (chunk.startsWith("`") && chunk.endsWith("`")) {
        return (
          <code key={j} className="rounded bg-muted px-1.5 py-0.5 font-mono text-sm">
            {chunk.slice(1, -1)}
          </code>
        );
      }
      if (chunk.startsWith("**") && chunk.endsWith("**")) {
        return <strong key={j}>{chunk.slice(2, -2)}</strong>;
      }
      return chunk;
    });

    return (
      <p key={i} className={cn("whitespace-pre-wrap", textClassName ?? "text-base leading-relaxed")}>
        {inline}
      </p>
    );
  });

  return <div className={cn("flex flex-col", hasBlocks ? "gap-3" : "gap-1")}>{nodes}</div>;
}
