import { Skeleton } from "@/components/ui/skeleton";

export default function WikiLoading() {
  return (
    <main className="page-container">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-8 w-24" />
          <Skeleton className="h-4 w-72" />
        </div>
        <Skeleton className="h-9 w-32" />
      </div>

      <Skeleton className="mb-6 h-10 w-full max-w-md" />

      <div className="card-grid">
        {Array.from({ length: 6 }).map((_, i) => (
          <div className="card-base p-6" key={i}>
            <div className="flex items-center gap-2">
              <Skeleton className="h-5 w-5 rounded-full" />
              <Skeleton className="h-4 w-32" />
            </div>
            <Skeleton className="mt-3 h-3 w-full" />
            <Skeleton className="mt-1.5 h-3 w-3/4" />
          </div>
        ))}
      </div>
    </main>
  );
}
