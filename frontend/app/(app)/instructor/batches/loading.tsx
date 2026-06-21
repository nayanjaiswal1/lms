import { Skeleton } from "@/components/ui/skeleton";

export default function BatchesLoading() {
  return (
    <div className="page-container py-10">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-9 w-32" />
          <Skeleton className="h-4 w-64" />
        </div>
        <Skeleton className="h-10 w-32" />
      </div>
      <div className="card-grid mt-8">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton className="h-36" key={i} />
        ))}
      </div>
    </div>
  );
}
