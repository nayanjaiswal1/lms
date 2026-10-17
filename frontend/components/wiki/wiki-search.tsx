"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { useQueryState } from "nuqs";
import { toast } from "sonner";
import { apiFetch } from "@/lib/client/api";
import type { WikiPageDetail, WikiSearchResult } from "@/lib/server/wiki";
import ROUTES from "@/lib/routes";

import { Button } from "@/components/ui/button";
const DEBOUNCE_MS = 300;

interface WikiSearchProps {
  spaceSlug?: string;
}

export function WikiSearch({ spaceSlug }: WikiSearchProps) {
  const router = useRouter();
  const [query] = useQueryState("q", { defaultValue: "" });
  const [results, setResults] = useState<WikiSearchResult[] | null>(null);

  useEffect(() => {
    if (query.trim().length < 2) {
      setResults(null);
      return;
    }
    const t = setTimeout(() => void doSearch(query), DEBOUNCE_MS);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- doSearch only reads query/spaceSlug
  }, [query, spaceSlug]);

  async function doSearch(q: string) {
    const params = new URLSearchParams({ q });
    if (spaceSlug) params.set("space", spaceSlug);
    const data = await apiFetch<WikiSearchResult[]>(`/wiki/search?${params.toString()}`);
    setResults(data ?? []);
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
      {results !== null && (
        <ul className="flex flex-col gap-2">
          {results.length === 0 && <p className="text-sm text-muted-foreground">No pages found.</p>}
          {results.map((r) => (
            <li key={r.page_id}>
              <Button className="card-base card-interactive block w-full p-4 text-left" type="button" variant="unstyled" onClick={() => void openResult(r)}>
                <p className="font-medium text-foreground">{r.title}</p>
                <p className="text-xs text-muted-foreground">{r.space_name}</p>
                {r.excerpt && <p className="mt-1 line-clamp-2 text-sm text-muted-foreground">{r.excerpt}</p>}
              </Button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
