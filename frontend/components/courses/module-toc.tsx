import type { TocEntry } from "@/lib/courses/markdown";
import { cn } from "@/lib/utils";

interface ModuleTocProps {
  entries: TocEntry[];
}

export function ModuleToc({ entries }: ModuleTocProps) {
  if (entries.length === 0) return null;

  return (
    <nav aria-label="On this page" className="flex flex-col gap-2">
      <p className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">On this page</p>
      <ul className="flex list-none flex-col gap-0.5 border-l border-border">
        {entries.map((entry) => (
          <li key={entry.id}>
            {/* Plain anchor, not next/link: this is a same-page fragment
                scroll, and next/link's client routing mishandles hash-only
                hrefs (it can jump to the wrong heading). */}
            <a
              className={cn(
                "-ml-px block border-l-2 border-transparent py-1 text-sm text-muted-foreground transition-colors duration-fast hover:border-primary hover:text-foreground",
                entry.level === 2 ? "pl-3 font-medium" : "pl-6",
              )}
              href={`#${entry.id}`}
            >
              {entry.text}
            </a>
          </li>
        ))}
      </ul>
    </nav>
  );
}
