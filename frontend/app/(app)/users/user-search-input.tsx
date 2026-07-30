"use client";

import { useTransition } from "react";
import { useQueryState } from "nuqs";
import { Loader2, Search as SearchIcon, X } from "lucide-react";
import { Input } from "@/components/ui/input";

const DEBOUNCE_MS = 300;

// Controlled leaf so the native searchParams-driven table (page.tsx) gets a
// working clear affordance and a loading indicator during the server
// round-trip — a plain uncontrolled <input type="search"> can't do either.
export function UserSearchInput() {
  const [isPending, startTransition] = useTransition();
  const [search, setSearch] = useQueryState("search", {
    defaultValue: "",
    shallow: false,
    throttleMs: DEBOUNCE_MS,
    startTransition,
  });

  return (
    <div className="relative w-full sm:max-w-sm">
      <SearchIcon
        aria-hidden
        className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"
      />
      <Input
        aria-label="Search users by name or email"
        className="pl-9 pr-9 [&::-webkit-search-cancel-button]:appearance-none"
        placeholder="Search by name or email…"
        type="search"
        value={search}
        onChange={(e) => void setSearch(e.target.value)}
      />
      {isPending ? (
        <Loader2
          aria-hidden
          className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 animate-spin text-muted-foreground"
        />
      ) : (
        search && (
          <button
            aria-label="Clear search"
            className="touch-target absolute right-0 top-1/2 -translate-y-1/2 text-muted-foreground transition-colors hover:text-foreground"
            type="button"
            onClick={() => void setSearch("")}
          >
            <X aria-hidden className="h-4 w-4" />
          </button>
        )
      )}
    </div>
  );
}
