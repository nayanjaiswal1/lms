import { Send, Sparkles } from "lucide-react";

interface AiAssistantCardProps {
  placeholder: string;
  suggestions: string[];
}

export function AiAssistantCard({ placeholder, suggestions }: AiAssistantCardProps) {
  return (
    <section id="ai-assistant" aria-label="AI Task Assistant" className="scroll-mt-20 space-y-3 rounded-2xl border border-(--ae-line)/80 bg-(--ae-card) p-4 shadow-sm">
      <div className="flex items-center gap-2">
        <Sparkles className="size-4 text-(--ae-brand)" aria-hidden />
        <h2 className="text-sm font-bold text-(--ae-ink)">AI Task Assistant</h2>
      </div>
      <label className="relative block">
        <span className="sr-only">Ask the assistant</span>
        <input
          type="text"
          placeholder={placeholder}
          className="w-full rounded-xl border border-(--ae-line) bg-(--ae-card) py-3 pl-3.5 pr-12 text-xs text-(--ae-text) transition-all placeholder:text-(--ae-faint) focus:border-(--ae-brand-500) focus:outline-none focus:ring-2 focus:ring-(--ae-brand-500)/20"
        />
        <button
          type="button"
          aria-label="Send to assistant"
          className="absolute right-2 top-2 rounded-lg bg-(--ae-brand) p-1.5 text-(--ae-card) transition-colors hover:bg-(--ae-brand-hover)"
        >
          <Send className="size-4" aria-hidden />
        </button>
      </label>
      <div className="flex flex-wrap gap-2 pt-1">
        {suggestions.map((s) => (
          <button
            key={s}
            type="button"
            className="rounded-full border border-(--ae-line) px-3 py-1.5 text-xs font-medium text-(--ae-dim) transition-colors hover:border-(--ae-line-strong) hover:bg-(--ae-hover)"
          >
            {s}
          </button>
        ))}
      </div>
    </section>
  );
}
