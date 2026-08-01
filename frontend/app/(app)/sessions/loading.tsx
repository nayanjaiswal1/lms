import { Skeleton } from "@/components/ui/skeleton";

export default function SessionsLoading() {
  return (
    <main className="page-container">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-9 w-40" />
          <Skeleton className="h-4 w-64" />
        </div>
        <Skeleton className="h-8 w-28 rounded-md" />
      </div>

      <div className="flex flex-col gap-4">
        <Skeleton className="h-7 w-32" />
        <div className="card-grid">
          {Array.from({ length: 3 }).map((_, i) => (
            <Skeleton className="h-32" key={i} />
          ))}
        </div>
      </div>

      <div className="mt-10 flex flex-col gap-4">
        <Skeleton className="h-7 w-24" />
        <div className="card-grid">
          {Array.from({ length: 3 }).map((_, i) => (
            <Skeleton className="h-32" key={i} />
          ))}
        </div>
      </div>
    </main>
  );
}
