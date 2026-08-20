import { Skeleton } from "@/components/ui/skeleton";

export default function HighlightsLoading() {
  return (
    <main className="page-container">
      <div className="mb-6 flex flex-col gap-2">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-4 w-56" />
      </div>

      <div className="flex flex-col gap-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton className="h-28 w-full rounded-lg" key={i} />
        ))}
      </div>
    </main>
  );
}
