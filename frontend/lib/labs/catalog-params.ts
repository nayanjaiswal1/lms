import { parseAsString } from "nuqs/server"

/** URL value meaning "no filter" (a Select can't hold an empty string). */
export const CATALOG_ALL = "all"

// Shared by the server loader (page.tsx) and the client filter bar so the URL
// is the single source of truth for catalog filters.
export const labCatalogParsers = {
  kind: parseAsString.withDefault(CATALOG_ALL),
  stack: parseAsString.withDefault(CATALOG_ALL),
  category: parseAsString.withDefault(CATALOG_ALL),
  difficulty: parseAsString.withDefault(CATALOG_ALL),
}

export type LabCatalogFilters = {
  [K in keyof typeof labCatalogParsers]: string
}

/** GET /api/labs/catalog query string; "all" filters are omitted. */
export function catalogQuery(filters: LabCatalogFilters): string {
  const params = new URLSearchParams()
  for (const [key, value] of Object.entries(filters)) {
    if (value !== CATALOG_ALL) params.set(key, value)
  }
  const qs = params.toString()
  return qs ? `?${qs}` : ""
}

/** "react-hooks" -> "React hooks". */
export function humanizeSlug(slug: string): string {
  const spaced = slug.replace(/-/g, " ")
  return spaced.charAt(0).toUpperCase() + spaced.slice(1)
}
