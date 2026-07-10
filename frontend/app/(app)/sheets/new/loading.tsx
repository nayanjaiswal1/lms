import { Skeleton } from "@/components/ui/skeleton";

export default function NewSheetLoading() {
  return (
    <main className="page-container py-6">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-8 w-48" />
          <Skeleton className="h-4 w-96" />
        </div>
      </div>

      <div className="grid-responsive-2 lg:grid-cols-3">
        {Array.from({ length: 3 }).map((_, i) => (
          <Skeleton className="h-28 w-full" key={i} />
        ))}
      </div>

      <Skeleton className="h-64 w-full mt-6" />
    </main>
  );
}
