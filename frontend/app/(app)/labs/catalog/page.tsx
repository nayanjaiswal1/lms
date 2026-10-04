import type { Metadata } from "next"
import { createLoader, type SearchParams } from "nuqs/server"
import { Breadcrumb } from "@/components/shared/breadcrumb"
import { CatalogCard } from "@/app/(app)/labs/catalog/catalog-card"
import { CatalogFilters } from "@/app/(app)/labs/catalog/catalog-filters"
import { apiGet } from "@/lib/server/api"
import { catalogQuery, labCatalogParsers } from "@/lib/labs/catalog-params"
import { groupCatalog } from "@/lib/labs/kinds/catalog"
import ROUTES from "@/lib/routes"
import type { LabCatalogEntry } from "@/lib/labs"

export const metadata: Metadata = {
  title: "Debug Labs",
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
    <main className="page-container flex flex-col gap-8">
      <Breadcrumb items={[{ label: "Labs", href: ROUTES.LABS_CATALOG }, { label: "Catalog" }]} />
      <header className="page-header">
        <h1 className="page-title">Debug labs</h1>
        <p className="text-muted-foreground">
          Broken, realistic apps to debug in a browser IDE. Work through the levels in order, or
          jump to what you want to practice.
        </p>
      </header>

      <CatalogFilters />

      {groups.length === 0 ? (
        <div className="empty-state">
          <p className="text-sm text-muted-foreground">No labs match these filters.</p>
        </div>
      ) : (
        groups.map(({ group, entries: groupEntries }) => (
          <section
            aria-labelledby={`group-${group.id}`}
            className="flex flex-col gap-4"
            key={`${groupEntries[0].lab_type}-${group.id}`}
          >
            <div className="flex flex-col gap-1">
              <h2 className="section-title" id={`group-${group.id}`}>
                {group.label}
              </h2>
              {group.description && (
                <p className="text-sm text-muted-foreground">{group.description}</p>
              )}
            </div>
            <div className="card-grid">
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
