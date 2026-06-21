import { Skeleton } from "@/components/ui/skeleton";

export default function AssessmentsLoading() {
  return (
    <div className="page-container py-10">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-9 w-48" />
          <Skeleton className="h-4 w-72" />
        </div>
      </div>
      <div className="grid-stats mt-4 grid gap-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton className="h-20" key={i} />
        ))}
      </div>
      <div className="card-grid mt-8">
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton className="h-48" key={i} />
        ))}
      </div>
    </div>
  );
}
