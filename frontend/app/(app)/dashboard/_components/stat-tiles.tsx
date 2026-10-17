import Link from "next/link";

import { Skeleton } from "@/components/ui/skeleton";

export interface StatTileData {
  label: string;
  value: string | number;
  href?: string;
}

// Shared stat row for the role dashboards (same .grid-stats + card-base look
// as the lab usage page).
export function StatTiles({ tiles }: { tiles: StatTileData[] }) {
  return (
    <div className="grid-stats">
      {tiles.map((t) => {
        const body = (
          <>
            <p className="text-sm text-muted-foreground">{t.label}</p>
            <p className="mt-1 text-3xl font-bold tabular-nums tracking-tight">{t.value}</p>
          </>
        );
        return t.href ? (
          <Link className="card-base card-interactive p-6" href={t.href} key={t.label}>{body}</Link>
        ) : (
          <div className="card-base p-6" key={t.label}>{body}</div>
        );
      })}
    </div>
  );
}

export function StatTilesSkeleton() {
  return (
    <div className="grid-stats">
      {Array.from({ length: 4 }).map((_, i) => (
        <Skeleton className="h-24" key={i} />
      ))}
    </div>
  );
}

export function ListSkeleton({ rows = 3 }: { rows?: number }) {
  return (
    <div className="flex flex-col gap-3">
      {Array.from({ length: rows }).map((_, i) => (
        <Skeleton className="h-16" key={i} />
      ))}
    </div>
  );
}
