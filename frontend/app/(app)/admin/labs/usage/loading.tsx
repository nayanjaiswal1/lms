import { Skeleton } from "@/components/ui/skeleton";

export default function LabUsageLoading() {
  return (
    <div className="page-container">
      <div className="page-header">
        <Skeleton className="h-8 w-40" />
        <Skeleton className="h-9 w-48" />
      </div>

      <div className="grid-stats mt-8">
        <Skeleton className="h-24" />
        <Skeleton className="h-24" />
        <Skeleton className="h-24" />
        <Skeleton className="h-24" />
      </div>

      <div className="mt-8 flex flex-col gap-3">
        {Array.from({ length: 5 }).map((_, i) => (
          <Skeleton className="h-10 w-full" key={i} />
        ))}
      </div>
    </div>
  );
}
