import { Skeleton } from "@/components/ui/skeleton";

export default function RolesLoading() {
  return (
    <div className="page-container">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-9 w-24" />
          <Skeleton className="h-4 w-96" />
        </div>
        <Skeleton className="h-10 w-32" />
      </div>

      <div className="mt-6 flex flex-wrap items-center gap-3">
        <Skeleton className="h-9 w-40" />
        <Skeleton className="h-9 w-40" />
      </div>

      <div className="mt-6 flex flex-col gap-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton className="h-14 w-full" key={i} />
        ))}
      </div>
    </div>
  );
}
