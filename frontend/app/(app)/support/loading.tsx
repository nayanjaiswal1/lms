import { Skeleton } from "@/components/ui/skeleton";

export default function SupportLoading() {
  return (
    <main className="page-container">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-8 w-40" />
          <Skeleton className="h-4 w-72" />
        </div>
        <Skeleton className="h-9 w-32" />
      </div>

      <div className="flex flex-col gap-3">
        {Array.from({ length: 4 }).map((_, i) => (
          <div className="card-base flex items-center gap-4 p-4" key={i}>
            <div className="min-w-0 flex-1">
              <Skeleton className="h-4 w-48" />
              <div className="mt-2 flex gap-1.5">
                <Skeleton className="h-5 w-16 rounded-full" />
                <Skeleton className="h-4 w-24" />
              </div>
            </div>
            <Skeleton className="h-4 w-4 shrink-0" />
          </div>
        ))}
      </div>
    </main>
  );
}
