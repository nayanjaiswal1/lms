"use client"

import { useTransition } from "react"
import { useQueryStates } from "nuqs"
import { Button } from "@/components/ui/button"
import { FilterSelect } from "@/components/labs/filter-select"
import { CATALOG_ALL, humanizeSlug, labCatalogParsers } from "@/lib/labs/catalog-params"
import { CATALOG_DIFFICULTIES, LAB_KIND_CATALOG, type CatalogOption } from "@/lib/labs/kinds/catalog"

const stackOptions: CatalogOption[] = [
  ...new Map(
    Object.values(LAB_KIND_CATALOG)
      .flatMap((c) => c.stacks)
      .map((s) => [s.value, s]),
  ).values(),
]

const categoryOptions: CatalogOption[] = [
  ...new Set(Object.values(LAB_KIND_CATALOG).flatMap((c) => c.groups.flatMap((g) => g.categories))),
].map((value) => ({ value, label: humanizeSlug(value) }))

interface CatalogFiltersProps {
  count: number
}

/** Stack / category / difficulty filters in the URL (server re-fetches on change), with result count and reset. */
export function CatalogFilters({ count }: CatalogFiltersProps) {
  const [isPending, startTransition] = useTransition()
  const [filters, setFilters] = useQueryStates(labCatalogParsers, {
    shallow: false,
    startTransition,
  })
  const isFiltered = [filters.stack, filters.category, filters.difficulty].some((v) => v !== CATALOG_ALL)

  return (
    <div
      aria-busy={isPending}
      aria-label="Catalog filters"
      className="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-center"
      role="group"
    >
      <FilterSelect
        allLabel="All stacks"
        allValue={CATALOG_ALL}
        label="Filter by stack"
        options={stackOptions}
        value={filters.stack}
        onChange={(stack) => void setFilters({ stack })}
      />
      <FilterSelect
        allLabel="All categories"
        allValue={CATALOG_ALL}
        label="Filter by category"
        options={categoryOptions}
        value={filters.category}
        onChange={(category) => void setFilters({ category })}
      />
      <FilterSelect
        allLabel="All difficulties"
        allValue={CATALOG_ALL}
        label="Filter by difficulty"
        options={CATALOG_DIFFICULTIES}
        value={filters.difficulty}
        onChange={(difficulty) => void setFilters({ difficulty })}
      />
      {isFiltered && (
        <Button
          size="sm"
          variant="ghost"
          onClick={() => void setFilters({ stack: null, category: null, difficulty: null })}
        >
          Reset filters
        </Button>
      )}
      <p aria-live="polite" className="text-sm text-muted-foreground sm:ml-auto">
        {count} {count === 1 ? "lab" : "labs"}
      </p>
    </div>
  )
}
