import { Skeleton } from "@/components/ui/skeleton";

export default function SheetsLoading() {
  return (
    <main className="page-container py-6">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-8 w-48" />
          <Skeleton className="h-4 w-72" />
        </div>
        <Skeleton className="h-9 w-32" />
      </div>

      <div className="card-grid">
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton className="h-28 w-full" key={i} />
        ))}
      </div>
    </main>
  );
}
