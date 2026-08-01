import { Skeleton } from "@/components/ui/skeleton";

export default function SessionCreditsLoading() {
  return (
    <div className="page-container">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-9 w-48" />
          <Skeleton className="h-4 w-72" />
        </div>
      </div>

      <div className="card-raised mb-8 flex items-center gap-4">
        <Skeleton className="h-14 w-14 rounded-full" />
        <div className="flex flex-col gap-2">
          <Skeleton className="h-9 w-16" />
          <Skeleton className="h-4 w-32" />
        </div>
      </div>

      <div className="mb-8">
        <Skeleton className="mb-4 h-7 w-32" />
        <div className="card-grid">
          {Array.from({ length: 3 }).map((_, i) => (
            <div className="card-base flex flex-col gap-3" key={i}>
              <Skeleton className="h-6 w-2/3" />
              <Skeleton className="h-4 w-full" />
              <Skeleton className="h-4 w-1/3" />
              <Skeleton className="h-8 w-1/2" />
              <Skeleton className="h-10 w-full" />
            </div>
          ))}
        </div>
      </div>

      <div>
        <Skeleton className="mb-4 h-7 w-24" />
        <div className="table-responsive flex flex-col gap-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton className="h-10" key={i} />
          ))}
        </div>
      </div>
    </div>
  );
}
