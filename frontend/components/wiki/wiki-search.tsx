"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { useQueryState } from "nuqs";
import { Search as SearchIcon } from "lucide-react";
import { toast } from "sonner";
import { Input } from "@/components/ui/input";
import { apiFetch } from "@/lib/client/api";
import type { WikiPageDetail, WikiSearchResult } from "@/lib/server/wiki";
import ROUTES from "@/lib/routes";

const DEBOUNCE_MS = 300;

interface WikiSearchProps {
  spaceSlug?: string;
}

export function WikiSearch({ spaceSlug }: WikiSearchProps) {
  const router = useRouter();
  const [query, setQuery] = useQueryState("q", { defaultValue: "" });
  const [results, setResults] = useState<WikiSearchResult[] | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  function runSearch(q: string) {
    if (timer.current) clearTimeout(timer.current);
    if (q.trim().length < 2) {
      setResults(null);
      return;
    }
    timer.current = setTimeout(() => void doSearch(q), DEBOUNCE_MS);
  }

  async function doSearch(q: string) {
    const params = new URLSearchParams({ q });
    if (spaceSlug) params.set("space", spaceSlug);
    const data = await apiFetch<WikiSearchResult[]>(`/wiki/search?${params.toString()}`);
    setResults(data ?? []);
  }

  function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    const next = e.target.value;
    void setQuery(next || null);
    runSearch(next);
  }

  async function openResult(result: WikiSearchResult) {
    const detail = await apiFetch<WikiPageDetail>(`/wiki/pages/${result.page_id}`);
    if (!detail) {
      toast.error("Couldn't open that page.");
      return;
    }
    router.push(ROUTES.wikiPage(detail.space_slug, ...detail.breadcrumb.map((b) => b.slug)));
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="relative">
        <SearchIcon aria-hidden className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
        <Input className="pl-9" placeholder="Search the wiki…" value={query} onChange={handleChange} />
      </div>
      {results !== null && (
        <ul className="flex flex-col gap-2">
          {results.length === 0 && <p className="text-sm text-muted-foreground">No pages found.</p>}
          {results.map((r) => (
            <li key={r.page_id}>
              <button className="card-base card-interactive block w-full p-4 text-left" type="button" onClick={() => void openResult(r)}>
                <p className="font-medium text-foreground">{r.title}</p>
                <p className="text-xs text-muted-foreground">{r.space_name}</p>
                {r.excerpt && <p className="mt-1 line-clamp-2 text-sm text-muted-foreground">{r.excerpt}</p>}
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
