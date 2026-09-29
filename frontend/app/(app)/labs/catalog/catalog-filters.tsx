"use client"

import { useTransition } from "react"
import { Loader2 } from "lucide-react"
import { useQueryStates } from "nuqs"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { CATALOG_ALL, humanizeSlug, labCatalogParsers } from "@/lib/labs/catalog-params"
import { CATALOG_DIFFICULTIES, LAB_KIND_CATALOG, type CatalogOption } from "@/lib/labs/kinds/catalog"

const kindOptions: CatalogOption[] = Object.entries(LAB_KIND_CATALOG).map(([value, config]) => ({
  value,
  label: config.label,
}))

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

interface FilterSelectProps {
  label: string
  allLabel: string
  value: string
  options: CatalogOption[]
  onChange: (value: string) => void
}

function FilterSelect({ label, allLabel, value, options, onChange }: FilterSelectProps) {
  return (
    <Select value={value} onValueChange={onChange}>
      <SelectTrigger aria-label={label} className="w-full sm:w-44">
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value={CATALOG_ALL}>{allLabel}</SelectItem>
        {options.map((o) => (
          <SelectItem key={o.value} value={o.value}>
            {o.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}

/** Kind / stack / category / difficulty filters, stored in the URL (server re-fetches on change). */
export function CatalogFilters() {
  const [isPending, startTransition] = useTransition()
  const [filters, setFilters] = useQueryStates(labCatalogParsers, {
    shallow: false,
    startTransition,
  })

  return (
    <div aria-label="Catalog filters" className="flex flex-col gap-3 sm:flex-row sm:flex-wrap" role="group">
      <FilterSelect
        allLabel="All kinds"
        label="Filter by kind"
        options={kindOptions}
        value={filters.kind}
        onChange={(kind) => void setFilters({ kind })}
      />
      <FilterSelect
        allLabel="All stacks"
        label="Filter by stack"
        options={stackOptions}
        value={filters.stack}
        onChange={(stack) => void setFilters({ stack })}
      />
      <FilterSelect
        allLabel="All categories"
        label="Filter by category"
        options={categoryOptions}
        value={filters.category}
        onChange={(category) => void setFilters({ category })}
      />
      <FilterSelect
        allLabel="All difficulties"
        label="Filter by difficulty"
        options={CATALOG_DIFFICULTIES}
        value={filters.difficulty}
        onChange={(difficulty) => void setFilters({ difficulty })}
      />
      {isPending && (
        <Loader2 aria-label="Updating results" className="h-4 w-4 animate-spin self-center text-muted-foreground" />
      )}
    </div>
  )
}
