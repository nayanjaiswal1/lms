"use client";

import { useRef } from "react";
import { useQueryState } from "nuqs";
import { Search as SearchIcon } from "lucide-react";
import { Input } from "@/components/ui/input";

const DEBOUNCE_MS = 300;

export function JournalSearchBar() {
  const [query, setQuery] = useQueryState("q", { defaultValue: "", shallow: false });
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    const next = e.target.value;
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => void setQuery(next || null), DEBOUNCE_MS);
  }

  return (
    <div className="relative w-full sm:w-64">
      <SearchIcon aria-hidden className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
      <Input className="pl-9" defaultValue={query} placeholder="Search your learning…" onChange={handleChange} />
    </div>
  );
}
