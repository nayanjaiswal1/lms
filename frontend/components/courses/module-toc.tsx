"use client";

import { useState } from "react";
import type { TocEntry } from "@/lib/courses/markdown";
import { cn } from "@/lib/utils";

interface ModuleTocProps {
  entries: TocEntry[];
}

export function ModuleToc({ entries }: ModuleTocProps) {
  const [activeId, setActiveId] = useState<string | null>(null);

  // Scroll-spy: highlight the section currently being read. Set up in a ref
  // callback (with React 19 cleanup) rather than useEffect — the observer's
  // lifetime is exactly the nav element's mount/unmount.
  const observeHeadings = (node: HTMLElement | null) => {
    if (!node) return;
    const headings = entries
      .map((entry) => document.getElementById(entry.id))
      .filter((el): el is HTMLElement => el !== null);
    if (headings.length === 0) return;

    const observer = new IntersectionObserver(
      (observed) => {
        for (const entry of observed) {
          if (entry.isIntersecting) setActiveId(entry.target.id);
        }
      },
      // Fire when a heading crosses the top ~30% of the viewport.
      { rootMargin: "-80px 0px -70% 0px" },
    );
    for (const el of headings) observer.observe(el);
    return () => observer.disconnect();
  };

  if (entries.length === 0) return null;

  return (
    <nav aria-label="On this page" className="flex flex-col gap-2" ref={observeHeadings}>
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
                entry.id === activeId && "border-primary text-foreground",
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
