import { Skeleton } from "@/components/ui/skeleton";

export default function CoursesLoading() {
  return (
    <main className="page-container">
      <div className="mb-6 flex items-center justify-between gap-4">
        <Skeleton className="h-8 w-32" />
        <Skeleton className="h-9 w-32" />
      </div>

      <div className="card-grid">
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton className="h-56 rounded-lg" key={i} />
        ))}
      </div>
    </main>
  );
}
