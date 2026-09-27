import { Skeleton } from "@/components/ui/skeleton";

export default function WorkItemLoading() {
  return (
    <div className="flex flex-col gap-6">
      <Skeleton className="h-5 w-64" />
      <div className="flex flex-col gap-6 lg:flex-row">
        <div className="flex min-w-0 flex-1 flex-col gap-4">
          <Skeleton className="h-8 w-full sm:w-2/3" />
          <Skeleton className="h-40 w-full" />
        </div>
        <div className="flex w-full flex-col gap-4 lg:w-72 lg:shrink-0">
          <Skeleton className="h-32 w-full" />
          <Skeleton className="h-24 w-full" />
          <Skeleton className="h-24 w-full" />
        </div>
      </div>
    </div>
  );
}
