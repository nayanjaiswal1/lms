import { Skeleton } from "@/components/ui/skeleton";

export default function RequirementDetailLoading() {
  return (
    <div className="page-container">
      <Skeleton className="h-4 w-40" />
      <div className="page-header items-start mt-4">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-9 w-64" />
          <Skeleton className="h-4 w-56" />
        </div>
        <Skeleton className="h-10 w-32" />
      </div>
      <Skeleton className="mt-4 h-16 w-full" />
      <Skeleton className="mt-10 h-64 w-full" />
    </div>
  );
}
