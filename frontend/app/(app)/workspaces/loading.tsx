import { Skeleton } from "@/components/ui/skeleton";

export default function WorkspacesLoading() {
  return (
    <div className="page-container">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-9 w-40" />
          <Skeleton className="h-4 w-72" />
        </div>
        <Skeleton className="h-10 w-40" />
      </div>
      <Skeleton className="mt-6 h-64 w-full" />
    </div>
  );
}
