import { Skeleton } from "@/components/ui/skeleton";

export default function CoursesLoading() {
  return (
    <main className="page-container">
      <div className="mb-6 flex-between gap-4">
        <Skeleton className="h-8 w-32" />
        <Skeleton className="h-9 w-32" />
      </div>

      <Skeleton className="mb-8 h-24 rounded-lg" />
      <Skeleton className="mb-4 h-6 w-32" />
      <Skeleton className="mb-6 h-24 rounded-lg" />

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton className="h-60 rounded-lg" key={i} />
        ))}
      </div>
    </main>
  );
}
