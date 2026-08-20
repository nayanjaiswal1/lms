import { Skeleton } from "@/components/ui/skeleton";

export default function CouponsLoading() {
  return (
    <div className="page-container">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-8 w-28" />
          <Skeleton className="h-4 w-72" />
        </div>
        <Skeleton className="h-10 w-36" />
      </div>

      <div className="mt-6 flex flex-col gap-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton className="h-14 w-full" key={i} />
        ))}
      </div>
    </div>
  );
}
