import { Skeleton } from "@/components/ui/skeleton";

export default function MentoringLoading() {
  return (
    <main className="page-container">
      <div className="grid-stats mb-8">
        {Array.from({ length: 3 }).map((_, i) => (
          <Skeleton className="h-20" key={i} />
        ))}
      </div>

      <Skeleton className="mb-4 h-5 w-32" />
      <div className="card-grid">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton className="h-36" key={i} />
        ))}
      </div>
    </main>
  );
}
