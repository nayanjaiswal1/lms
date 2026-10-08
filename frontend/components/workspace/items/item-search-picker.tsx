"use client";

import { Button } from "@/components/ui/button";
import { useRef, useState, useTransition } from "react";
import { Input } from "@/components/ui/input";
import { searchWorkItemsAction } from "@/lib/workspace/items-actions";
import type { ItemType, WorkItem } from "@/lib/workspace/types";

const DEBOUNCE_MS = 300;
const MIN_QUERY_LENGTH = 2;

interface ItemSearchPickerProps {
  workspaceId: string;
  filterTypes?: ItemType[];
  excludeItemId?: string;
  value: WorkItem | null;
  onChange: (item: WorkItem | null) => void;
  placeholder: string;
}

/** Plain input + inline (non-portaled) results list — deliberately not a
 * Radix Popover/Command combobox: this picker is used inside AlertDialogs,
 * and a portaled Popper would hit the Popover-in-Dialog scroll lock gotcha
 * (docs/frontend-gotchas.md) for no benefit here since there's no multi-select
 * or keyboard-nav need. Debounced search is wired straight into the input's
 * onChange (no useEffect), same pattern as components/messaging/ask-question.tsx. */
export function ItemSearchPicker({ workspaceId, filterTypes, excludeItemId, value, onChange, placeholder }: ItemSearchPickerProps) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<WorkItem[]>([]);
  const [searching, startSearch] = useTransition();
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  function handleChange(next: string) {
    setQuery(next);
    if (value) onChange(null);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (next.trim().length < MIN_QUERY_LENGTH) {
      setResults([]);
      return;
    }
    debounceRef.current = setTimeout(() => {
      startSearch(async () => {
        const result = await searchWorkItemsAction(workspaceId, { q: next.trim(), type: filterTypes, limit: 8 });
        setResults(result.ok ? (result.data?.items.filter((i) => i.id !== excludeItemId) ?? []) : []);
      });
    }, DEBOUNCE_MS);
  }

  return (
    <div className="flex flex-col gap-1.5">
      <Input
        aria-label={placeholder}
        placeholder={placeholder}
        value={value ? `${value.key} — ${value.title}` : query}
        onChange={(e) => handleChange(e.target.value)}
      />
      {searching && <p className="text-xs text-muted-foreground">Searching…</p>}
      {!value && !searching && results.length > 0 && (
        <ul className="flex max-h-40 flex-col gap-1 overflow-y-auto rounded-md border border-border p-1">
          {results.map((r) => (
            <li key={r.id}>
              <Button className="w-full rounded-sm px-2 py-1.5 text-left text-sm hover:bg-muted"
                type="button"
                variant="unstyled"
                onClick={() => { onChange(r); setQuery(""); setResults([]); }}
              >
                <span className="font-mono text-xs text-muted-foreground">{r.key}</span> {r.title}
              </Button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
