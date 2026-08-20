import { Skeleton } from "@/components/ui/skeleton";

export default function ContentReportsLoading() {
  return (
    <div className="page-container">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-8 w-44" />
          <Skeleton className="h-4 w-80" />
        </div>
      </div>

      <div className="mt-8 flex flex-col gap-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton className="h-16 w-full" key={i} />
        ))}
      </div>
    </div>
  );
}
