import { Skeleton } from "@/components/ui/skeleton";

export default function CalendarLoading() {
  return (
    <main aria-busy className="page-container">
      <div className="mb-6 flex flex-col gap-1">
        <Skeleton className="h-8 w-32" />
        <Skeleton className="hidden h-4 w-80 sm:block" />
      </div>

      <div className="mb-4 flex flex-col gap-3">
        <div className="flex items-center gap-2">
          <Skeleton className="h-7 flex-1 sm:max-w-xs" />
          <Skeleton className="h-11 w-16 lg:h-9" />
          <Skeleton className="h-11 w-24 lg:h-9 lg:w-20" />
        </div>
        <div className="flex flex-col gap-2 md:flex-row md:justify-between">
          <Skeleton className="h-12 w-full md:h-10 md:w-72" />
          <Skeleton className="h-11 w-full md:w-96 lg:h-10" />
        </div>
      </div>

      <div className="grid grid-cols-7 gap-px overflow-hidden rounded-lg border border-border bg-border">
        {Array.from({ length: 7 }).map((_, i) => (
          <div className="flex justify-center bg-muted py-2" key={`h${i}`}>
            <Skeleton className="h-3 w-6" />
          </div>
        ))}
        {Array.from({ length: 35 }).map((_, i) => (
          <div className="flex min-h-16 flex-col items-center gap-1.5 bg-card p-1 sm:min-h-28 sm:items-start sm:p-1.5" key={i}>
            <Skeleton className="h-5 w-5 rounded-full" />
            {i % 3 === 0 && <Skeleton className="hidden h-4 w-full sm:block" />}
          </div>
        ))}
      </div>
    </main>
  );
}
