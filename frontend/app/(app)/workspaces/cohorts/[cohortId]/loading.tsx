import { Skeleton } from "@/components/ui/skeleton";

export default function CohortLoading() {
  return (
    <div className="page-container">
      <Skeleton className="h-4 w-40" />
      <div className="mt-4 flex flex-col gap-2">
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-4 w-48" />
      </div>
      <Skeleton className="mt-6 h-10 w-80" />
      <div className="mt-6 flex flex-col gap-3">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton className="h-16" key={i} />
        ))}
      </div>
    </div>
  );
}
