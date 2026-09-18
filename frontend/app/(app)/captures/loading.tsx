import { Skeleton } from "@/components/ui/skeleton";

export default function CapturesLoading() {
  return (
    <main className="page-container">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-8 w-40" />
          <Skeleton className="h-4 w-96" />
        </div>
      </div>

      <Skeleton className="h-28 w-full rounded-lg" />

      <div className="grid-responsive-2 mt-6 gap-3">
        <Skeleton className="h-32 w-full rounded-lg" />
        <Skeleton className="h-32 w-full rounded-lg" />
        <Skeleton className="h-32 w-full rounded-lg" />
        <Skeleton className="h-32 w-full rounded-lg" />
      </div>
    </main>
  );
}
