import { Skeleton } from "@/components/ui/skeleton";

export default function BoardRequirementLoading() {
  return (
    <div className="page-container-sm">
      <Skeleton className="h-4 w-40" />
      <div className="mb-4 mt-4 flex flex-col gap-2">
        <Skeleton className="h-9 w-64" />
        <Skeleton className="h-4 w-48" />
      </div>
      <Skeleton className="h-24 w-full" />
      <Skeleton className="mt-8 h-40 w-full" />
    </div>
  );
}
