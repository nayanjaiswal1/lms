import { Skeleton } from "@/components/ui/skeleton";

export default function DashboardLoading() {
  return (
    <main className="page-container">
      <div className="mb-8 flex flex-col gap-2">
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-4 w-48" />
      </div>

      <div className="grid grid-cols-1 gap-8 lg:grid-cols-3">
        <div className="flex flex-col gap-8 lg:col-span-2">
          <div>
            <Skeleton className="mb-4 h-5 w-32" />
            <div className="card-grid-2">
              <Skeleton className="h-40" />
              <Skeleton className="h-40" />
            </div>
          </div>
          <div>
            <Skeleton className="mb-4 h-5 w-40" />
            <Skeleton className="h-48 w-full rounded-lg" />
          </div>
        </div>

        <div className="flex flex-col gap-6">
          <Skeleton className="h-44 w-full rounded-lg" />
          <Skeleton className="h-56 w-full rounded-lg" />
        </div>
      </div>
    </main>
  );
}
