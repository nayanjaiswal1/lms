import { Skeleton } from "@/components/ui/skeleton";

export default function ActivityLoading() {
  return (
    <main className="page-container">
      <div className="mb-8 flex flex-col gap-2">
        <Skeleton className="h-8 w-40" />
      </div>

      <div className="flex flex-col gap-8">
        {Array.from({ length: 3 }).map((_, group) => (
          <section key={group}>
            <Skeleton className="mb-3 h-5 w-32" />
            <div className="flex flex-col gap-2">
              {Array.from({ length: 3 }).map((_, row) => (
                <div className="flex items-center gap-3 p-3" key={row}>
                  <Skeleton className="h-9 w-9 shrink-0 rounded-lg" />
                  <div className="min-w-0 flex-1">
                    <Skeleton className="mb-1 h-4 w-48" />
                    <Skeleton className="h-3 w-32" />
                  </div>
                </div>
              ))}
            </div>
          </section>
        ))}
      </div>
    </main>
  );
}
