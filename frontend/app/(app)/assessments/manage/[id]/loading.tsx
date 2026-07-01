import { Skeleton } from "@/components/ui/skeleton";

export default function AssessmentBuilderLoading() {
  return (
    <div className="page-container py-10">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-9 w-64" />
          <Skeleton className="h-4 w-48" />
        </div>
        <Skeleton className="h-10 w-28" />
      </div>
      <div className="mt-8 grid gap-8 lg:grid-cols-2">
        <div className="flex flex-col gap-3">
          <Skeleton className="h-6 w-48" />
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton className="h-16" key={i} />
          ))}
        </div>
        <div className="flex flex-col gap-3">
          <Skeleton className="h-6 w-48" />
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton className="h-14" key={i} />
          ))}
        </div>
      </div>
    </div>
  );
}
