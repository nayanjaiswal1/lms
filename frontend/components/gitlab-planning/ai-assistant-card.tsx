import { Send, Sparkles } from "lucide-react";

interface AiAssistantCardProps {
  placeholder: string;
  suggestions: string[];
}

export function AiAssistantCard({ placeholder, suggestions }: AiAssistantCardProps) {
  return (
    <section aria-label="AI Task Assistant" className="scroll-mt-20 space-y-3 card-base shadow-card" id="ai-assistant">
      <div className="flex items-center gap-2">
        <Sparkles aria-hidden className="size-4 text-primary" />
        <h2 className="text-sm font-bold text-foreground">AI Task Assistant</h2>
      </div>
      <label className="relative block">
        <span className="sr-only">Ask the assistant</span>
        <input
          className="w-full rounded-xl border border-border bg-card py-3 pl-3.5 pr-12 text-xs text-foreground transition-all placeholder:text-muted-foreground focus:border-(--ae-brand-500) focus:outline-none focus:ring-2 focus:ring-(--ae-brand-500)/20"
          placeholder={placeholder}
          type="text"
        />
        <button
          aria-label="Send to assistant"
          className="absolute right-2 top-2 rounded-lg bg-primary p-1.5 text-(--ae-card) transition-colors hover:bg-(--ae-brand-hover)"
          type="button"
        >
          <Send aria-hidden className="size-4" />
        </button>
      </label>
      <div className="flex flex-wrap gap-2 pt-1">
        {suggestions.map((s) => (
          <button
            className="rounded-full border border-border px-3 py-1.5 text-xs font-medium text-muted-foreground transition-colors hover:border-border hover:bg-accent"
            key={s}
            type="button"
          >
            {s}
          </button>
        ))}
      </div>
    </section>
  );
}
