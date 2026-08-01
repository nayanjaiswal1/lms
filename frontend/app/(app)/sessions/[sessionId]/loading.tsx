import { Skeleton } from "@/components/ui/skeleton";

export default function SessionDetailLoading() {
  return (
    <main className="page-container">
      <Skeleton className="mb-4 h-5 w-32" />

      <div className="flex flex-col gap-6">
        <div className="flex flex-col gap-3 rounded-xl border border-border bg-card p-6">
          <div className="flex items-start justify-between gap-3">
            <Skeleton className="h-8 w-56" />
            <Skeleton className="h-5 w-20 rounded-md" />
          </div>
          <Skeleton className="h-4 w-64" />
          <Skeleton className="h-4 w-40" />
          <Skeleton className="mt-2 h-16 w-full" />
          <div className="mt-2 flex gap-2">
            <Skeleton className="h-9 w-32 rounded-md" />
            <Skeleton className="h-9 w-32 rounded-md" />
          </div>
        </div>

        <Skeleton className="h-40 w-full rounded-xl" />
        <Skeleton className="h-24 w-full rounded-xl" />
        <Skeleton className="h-32 w-full rounded-xl" />
      </div>
    </main>
  );
}
