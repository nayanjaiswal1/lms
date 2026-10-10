import type { Metadata } from "next"
import { createLoader, type SearchParams } from "nuqs/server"
import { CatalogCard } from "@/app/(app)/labs/catalog/catalog-card"
import { CatalogFilters } from "@/app/(app)/labs/catalog/catalog-filters"
import { apiGet } from "@/lib/server/api"
import { catalogQuery, labCatalogParsers } from "@/lib/labs/catalog-params"
import { groupCatalog } from "@/lib/labs/kinds/catalog"
import type { LabCatalogEntry } from "@/lib/labs"

export const metadata: Metadata = {
  title: "Labs",
  robots: { index: false, follow: false },
}

const loadFilters = createLoader(labCatalogParsers)

interface PageProps {
  searchParams: Promise<SearchParams>
}

export default async function LabCatalogPage({ searchParams }: PageProps) {
  const filters = await loadFilters(searchParams)
  const entries = await apiGet<LabCatalogEntry[]>(`/api/labs/catalog${catalogQuery(filters)}`)
  const groups = groupCatalog(entries)

  return (
    <main className="page-container flex flex-col gap-6">
      <header className="flex flex-col gap-1">
        <h1 className="page-title">Labs</h1>
        <p className="text-sm text-muted-foreground">
          Debug realistic broken apps in a browser IDE, level by level or by topic.
        </p>
      </header>

      <CatalogFilters count={entries.length} />

      {groups.length === 0 ? (
        <div className="empty-state">
          <p className="text-sm text-muted-foreground">No labs match these filters.</p>
        </div>
      ) : (
        groups.map(({ group, entries: groupEntries }) => (
          <section
            aria-labelledby={`group-${group.id}`}
            className="flex flex-col gap-3"
            key={`${groupEntries[0].lab_type}-${group.id}`}
          >
            <div className="flex flex-col gap-0.5">
              <h2 className="subsection-title" id={`group-${group.id}`}>
                {group.label}
                <span className="ml-2 text-sm font-normal text-muted-foreground">
                  {groupEntries.filter((e) => e.status === "completed").length} of{" "}
                  {groupEntries.length} passed
                </span>
              </h2>
              {group.description && (
                <p className="text-sm text-muted-foreground">{group.description}</p>
              )}
            </div>
            <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-4">
              {groupEntries.map((entry) => (
                <CatalogCard entry={entry} key={entry.lab_id} />
              ))}
            </div>
          </section>
        ))
      )}
    </main>
  )
}
