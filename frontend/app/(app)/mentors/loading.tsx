import { Skeleton } from "@/components/ui/skeleton";

export default function MentorsLoading() {
  return (
    <main className="page-container">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-8 w-32" />
          <Skeleton className="h-5 w-full sm:w-80" />
        </div>
        <Skeleton className="h-11 w-44" />
      </div>

      <div className="flex flex-col gap-10">
        <div className="card-base flex items-center gap-3 border-l-4 border-l-primary">
          <Skeleton className="h-16 w-16 shrink-0 rounded-full" />
          <div className="flex flex-1 flex-col gap-2">
            <Skeleton className="h-4 w-40" />
            <Skeleton className="h-3 w-56 max-w-full" />
          </div>
        </div>

        <div className="flex flex-col gap-4">
          <Skeleton className="h-7 w-40" />
          <Skeleton className="h-11 w-full sm:max-w-md" />
          <div className="flex flex-wrap gap-2">
            {Array.from({ length: 6 }).map((_, i) => (
              <Skeleton className="h-9 w-20 rounded-full" key={i} />
            ))}
          </div>
          <div className="card-grid">
            {Array.from({ length: 6 }).map((_, i) => (
              <div className="card-base flex flex-col gap-4" key={i}>
                <div className="flex items-start gap-3">
                  <Skeleton className="h-16 w-16 shrink-0 rounded-full" />
                  <div className="flex flex-1 flex-col gap-2">
                    <Skeleton className="h-4 w-3/4" />
                    <Skeleton className="h-3 w-1/2" />
                  </div>
                </div>
                <Skeleton className="h-3 w-2/3" />
                <div className="flex gap-1.5">
                  <Skeleton className="h-5 w-14" />
                  <Skeleton className="h-5 w-16" />
                  <Skeleton className="h-5 w-12" />
                </div>
                <Skeleton className="h-11 w-full" />
              </div>
            ))}
          </div>
        </div>
      </div>
    </main>
  );
}
