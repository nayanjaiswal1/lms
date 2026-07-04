"use client"

import { RefreshCw } from "lucide-react"
import { Button } from "@/components/ui/button"
import { ScrollArea } from "@/components/ui/scroll-area"
import { Skeleton } from "@/components/ui/skeleton"
import type { LabResourcesData } from "@/lib/labs/files"

interface ResourceItem {
  kind?: string
  metadata?: { name?: string; namespace?: string }
}

interface LabResourcesPanelProps {
  resources: LabResourcesData | null
  hasLoaded: boolean
  isLoading: boolean
  onRefresh: () => void
}

// Groups the raw kubectl List response's flat `items` array by kind for a
// scannable read-only view. Refresh-on-demand only — no watch/stream.
function groupByKind(resources: LabResourcesData | null): Map<string, ResourceItem[]> {
  const groups = new Map<string, ResourceItem[]>()
  const items = Array.isArray(resources?.items) ? (resources.items as ResourceItem[]) : []
  for (const item of items) {
    const kind = item.kind ?? "Unknown"
    const existing = groups.get(kind) ?? []
    existing.push(item)
    groups.set(kind, existing)
  }
  return groups
}

export function LabResourcesPanel({
  resources,
  hasLoaded,
  isLoading,
  onRefresh,
}: LabResourcesPanelProps) {
  const groups = groupByKind(resources)

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center justify-between px-3 py-2 border-b border-border shrink-0">
        <span className="text-xs font-semibold text-muted-foreground uppercase tracking-wide">
          Cluster Resources
        </span>
        <Button
          className="h-6 gap-1.5 px-2 text-xs"
          disabled={isLoading}
          size="sm"
          variant="ghost"
          onClick={onRefresh}
        >
          <RefreshCw aria-hidden className={isLoading ? "h-3 w-3 animate-spin" : "h-3 w-3"} />
          Refresh
        </Button>
      </div>

      <ScrollArea className="flex-1">
        <div className="flex flex-col gap-4 p-3">
          {isLoading && (
            <div className="flex flex-col gap-2">
              <Skeleton className="h-5 w-24" />
              <Skeleton className="h-4 w-full" />
              <Skeleton className="h-4 w-3/4" />
            </div>
          )}

          {!isLoading && !hasLoaded && (
            <p className="text-xs text-muted-foreground text-center py-4">
              Click Refresh to see the objects you have created in this lab&apos;s cluster.
            </p>
          )}

          {!isLoading && hasLoaded && groups.size === 0 && (
            <p className="text-xs text-muted-foreground text-center py-4">
              No resources found yet.
            </p>
          )}

          {!isLoading &&
            Array.from(groups.entries()).map(([kind, items]) => (
              <div className="flex flex-col gap-1" key={kind}>
                <span className="text-xs font-semibold text-foreground">
                  {kind} ({items.length})
                </span>
                <div className="flex flex-col gap-0.5">
                  {items.map((item, i) => (
                    <div
                      className="text-xs font-mono text-muted-foreground truncate pl-2"
                      key={`${item.metadata?.namespace ?? "default"}/${item.metadata?.name ?? i}`}
                    >
                      {item.metadata?.namespace && item.metadata.namespace !== "default"
                        ? `${item.metadata.namespace}/`
                        : ""}
                      {item.metadata?.name ?? "(unnamed)"}
                    </div>
                  ))}
                </div>
              </div>
            ))}
        </div>
      </ScrollArea>
    </div>
  )
}
