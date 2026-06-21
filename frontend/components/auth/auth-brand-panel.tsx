import { Flame, GitFork, Sparkles, TerminalSquare } from "lucide-react";
import { BrandMark } from "@/components/shared/brand-mark";

// Marketing rail shown beside the form on lg+ screens. Static content, so it
// stays a server component. The data drives the list — no JSX duplication.
const HIGHLIGHTS = [
  {
    icon: TerminalSquare,
    title: "Practice in-browser",
    description: "Write, run, and get instant feedback without leaving the page.",
  },
  {
    icon: Sparkles,
    title: "AI-guided learning",
    description: "Personalised curriculum, hints, and spaced-repetition review.",
  },
  {
    icon: GitFork,
    title: "Own your stack",
    description: "Self-hosted and multi-tenant — no vendor lock-in, ever.",
  },
] as const;

export function AuthBrandPanel() {
  return (
    <aside className="relative hidden flex-col justify-between overflow-hidden border-r border-sidebar-border bg-sidebar p-12 lg:flex">
      {/* Decorative forge flame — sits behind the positioned content below. */}
      <Flame
        aria-hidden
        className="pointer-events-none absolute -bottom-16 -right-16 h-80 w-80 text-primary/5"
      />

      <BrandMark className="relative" />

      <div className="relative flex max-w-md flex-col gap-8">
        <h2 className="text-balance">Forge knowledge that lasts.</h2>
        <ul className="flex list-none flex-col gap-5">
          {HIGHLIGHTS.map(({ icon: Icon, title, description }) => (
            <li key={title} className="flex items-start gap-3">
              <span className="flex-center h-9 w-9 shrink-0 rounded-md bg-primary/10 text-primary">
                <Icon aria-hidden className="h-5 w-5" />
              </span>
              <span className="flex flex-col gap-0.5">
                <span className="font-semibold text-foreground">{title}</span>
                <span className="text-sm text-muted-foreground">{description}</span>
              </span>
            </li>
          ))}
        </ul>
      </div>

      <p className="relative max-w-sm text-sm text-muted-foreground">
        “The best way to learn is to build. MindForge gives you the anvil.”
      </p>
    </aside>
  );
}
