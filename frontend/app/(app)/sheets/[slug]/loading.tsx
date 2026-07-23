import { Skeleton } from "@/components/ui/skeleton";

export default function SheetDetailLoading() {
  return (
    <main className="page-container py-6">
      <Skeleton className="mb-4 h-5 w-20" />

      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-8 w-48" />
          <Skeleton className="h-4 w-72" />
        </div>
      </div>

      <div className="flex items-center justify-end gap-3 mb-3">
        <Skeleton className="h-8 w-40" />
      </div>

      <div className="flex flex-col gap-2">
        {Array.from({ length: 8 }).map((_, i) => (
          <Skeleton className="h-12 w-full" key={i} />
        ))}
      </div>
    </main>
  );
}
