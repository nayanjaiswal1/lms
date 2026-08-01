import { Skeleton } from "@/components/ui/skeleton";

export default function Loading() {
  return (
    <main className="page-container">
      <div className="mb-8 flex flex-col gap-2">
        <Skeleton className="h-8 w-56" />
        <Skeleton className="h-4 w-full max-w-md" />
      </div>

      <div className="grid-stats mb-6">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton className="h-24 rounded-lg" key={i} />
        ))}
      </div>

      <div className="mb-8 grid gap-3 sm:grid-cols-2">
        <Skeleton className="h-20 rounded-lg" />
        <Skeleton className="h-20 rounded-lg" />
      </div>

      <div className="flex flex-col gap-3">
        <Skeleton className="h-6 w-40" />
        <Skeleton className="h-28 rounded-lg" />
        <Skeleton className="h-28 rounded-lg" />
        <Skeleton className="h-28 rounded-lg" />
      </div>
    </main>
  );
}
