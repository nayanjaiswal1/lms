import { Skeleton } from "@/components/ui/skeleton";

export default function AssessmentResultsLoading() {
  return (
    <div className="page-container py-10">
      <div className="mb-6 flex flex-col gap-2">
        <Skeleton className="h-9 w-72" />
        <Skeleton className="h-4 w-32" />
      </div>
      <div className="grid-stats grid gap-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton className="h-20" key={i} />
        ))}
      </div>
      <div className="mt-10 flex flex-col gap-3">
        <Skeleton className="h-6 w-48" />
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton className="h-12" key={i} />
        ))}
      </div>
    </div>
  );
}
