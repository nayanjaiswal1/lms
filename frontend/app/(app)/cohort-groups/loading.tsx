import { Skeleton } from "@/components/ui/skeleton";

export default function CohortGroupsLoading() {
  return (
    <main className="page-container">
      <header className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-8 w-32" />
          <Skeleton className="h-4 w-80" />
        </div>
        <div className="flex gap-2">
          <Skeleton className="h-9 w-28" />
          <Skeleton className="h-9 w-28" />
        </div>
      </header>

      <div className="card-grid">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton className="h-36" key={i} />
        ))}
      </div>
    </main>
  );
}
