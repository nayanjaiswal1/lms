import { Skeleton } from "@/components/ui/skeleton";

export default function RoadmapLoading() {
  return (
    <main className="page-container">
      <div className="page-header">
        <Skeleton className="h-8 w-32" />
        <Skeleton className="h-9 w-40" />
      </div>

      <div className="flex flex-col gap-3">
        {Array.from({ length: 3 }).map((_, i) => (
          <Skeleton className="h-24 w-full rounded-lg" key={i} />
        ))}
      </div>
    </main>
  );
}
