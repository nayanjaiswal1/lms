"use client";

import { useTransition } from "react";
import { useQueryStates } from "nuqs";
import { FilterSelect } from "@/components/labs/filter-select";
import { BLOCK_KIND_OPTIONS, BLOCK_STACK_OPTIONS, BLOCKS_ALL, blockLibraryParsers } from "@/lib/labs/builder/library-params";

/** Kind / stack filters for the block library, stored in the URL (the server re-fetches). */
export function BlockLibraryFilters() {
  const [, startTransition] = useTransition();
  const [filters, setFilters] = useQueryStates(blockLibraryParsers, { shallow: false, startTransition });

  return (
    <div aria-label="Block filters" className="flex flex-col gap-3 sm:flex-row" role="group">
      <FilterSelect
        allLabel="All kinds"
        allValue={BLOCKS_ALL}
        label="Filter by kind"
        options={BLOCK_KIND_OPTIONS}
        value={filters.kind}
        onChange={(kind) => void setFilters({ kind })}
      />
      <FilterSelect
        allLabel="All stacks"
        allValue={BLOCKS_ALL}
        label="Filter by stack"
        options={BLOCK_STACK_OPTIONS}
        value={filters.stack}
        onChange={(stack) => void setFilters({ stack })}
      />
    </div>
  );
}
