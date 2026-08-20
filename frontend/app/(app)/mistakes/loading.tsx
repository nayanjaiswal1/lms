import { Skeleton } from "@/components/ui/skeleton";

export default function MistakesLoading() {
  return (
    <main className="page-container">
      <div className="page-header">
        <Skeleton className="h-8 w-40" />
        <Skeleton className="h-4 w-20" />
      </div>

      <div className="flex flex-col gap-8">
        <div className="card-base p-6">
          <Skeleton className="mb-1 h-5 w-32" />
          <Skeleton className="mb-4 h-4 w-64" />
          <Skeleton className="h-40 w-full" />
        </div>

        <div className="flex flex-col gap-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton className="h-16 w-full rounded-lg" key={i} />
          ))}
        </div>
      </div>
    </main>
  );
}
