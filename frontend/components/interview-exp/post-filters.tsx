"use client";

import { parseAsString, useQueryState } from "nuqs";
import { Input } from "@/components/ui/input";

export function PostFilters() {
  const [company, setCompany] = useQueryState("company", parseAsString.withDefault(""));
  const [position, setPosition] = useQueryState("position", parseAsString.withDefault(""));
  const [tag, setTag] = useQueryState("tag", parseAsString.withDefault(""));
  const [q, setQ] = useQueryState("q", parseAsString.withDefault(""));

  return (
    <div className="stack-sm">
      <Input
        aria-label="Search title"
        placeholder="Search title…"
        value={q}
        onChange={(e) => setQ(e.target.value || null)}
      />
      <Input
        aria-label="Filter by company"
        placeholder="Company"
        value={company}
        onChange={(e) => setCompany(e.target.value || null)}
      />
      <Input
        aria-label="Filter by position"
        placeholder="Position"
        value={position}
        onChange={(e) => setPosition(e.target.value || null)}
      />
      <Input
        aria-label="Filter by tag"
        placeholder="Tag (e.g. react)"
        value={tag}
        onChange={(e) => setTag(e.target.value || null)}
      />
    </div>
  );
}
