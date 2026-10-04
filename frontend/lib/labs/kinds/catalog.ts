import { DEBUG_CATALOG } from "@/lib/labs/kinds/debug"
import type { LabCatalogEntry, LabType } from "@/lib/labs"

export interface CatalogOption {
  value: string
  label: string
}

export interface CatalogGroup {
  id: string
  label: string
  description: string
  /** Catalog categories that belong to this group, in display order. */
  categories: string[]
}

/** Per-kind catalog extras: filter options and the learning-path grouping. */
export interface LabKindCatalogConfig {
  label: string
  stacks: CatalogOption[]
  groups: CatalogGroup[]
}

// Lab kinds that appear in the catalog. A new kind adds one entry here.
export const LAB_KIND_CATALOG: Partial<Record<LabType, LabKindCatalogConfig>> = {
  debug: DEBUG_CATALOG,
}

export const CATALOG_DIFFICULTIES: CatalogOption[] = [
  { value: "beginner", label: "Beginner" },
  { value: "intermediate", label: "Intermediate" },
  { value: "advanced", label: "Advanced" },
  { value: "expert", label: "Expert" },
]

const UNGROUPED: CatalogGroup = {
  id: "other",
  label: "Other",
  description: "",
  categories: [],
}

export interface GroupedCatalog {
  group: CatalogGroup
  entries: LabCatalogEntry[]
}

/** Buckets entries by their kind's learning-path groups; unknown categories land in "Other". */
export function groupCatalog(entries: LabCatalogEntry[]): GroupedCatalog[] {
  const buckets = new Map<string, GroupedCatalog>()
  for (const entry of entries) {
    const groups = LAB_KIND_CATALOG[entry.lab_type]?.groups ?? []
    const group = groups.find((g) => g.categories.includes(entry.category)) ?? UNGROUPED
    const key = `${entry.lab_type}:${group.id}`
    const bucket = buckets.get(key) ?? { group, entries: [] }
    bucket.entries.push(entry)
    buckets.set(key, bucket)
  }
  return [...buckets.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([, bucket]) => bucket)
}
