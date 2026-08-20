import { Skeleton } from "@/components/ui/skeleton";

export default function TeachLoading() {
  return (
    <main className="page-container">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-8 w-28" />
          <Skeleton className="h-4 w-72" />
        </div>
      </div>

      <div className="flex flex-col gap-8">
        {Array.from({ length: 3 }).map((_, g) => (
          <section key={g}>
            <Skeleton className="mb-4 h-3 w-24" />
            <div className="grid grid-cols-3 gap-x-2 gap-y-6 sm:grid-cols-4 lg:grid-cols-6">
              {Array.from({ length: 3 }).map((_, i) => (
                <div className="flex flex-col items-center gap-2" key={i}>
                  <Skeleton className="h-16 w-16 rounded-full" />
                  <Skeleton className="h-3 w-14" />
                </div>
              ))}
            </div>
          </section>
        ))}
      </div>
    </main>
  );
}
