import { Skeleton } from "@/components/ui/skeleton";

export default function WorkspaceLoading() {
  return (
    <div className="page-container">
      <Skeleton className="h-4 w-40" />
      <div className="page-header items-start mt-4">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-9 w-64" />
          <Skeleton className="h-4 w-56" />
        </div>
        <Skeleton className="h-9 w-32" />
      </div>
      <Skeleton className="mt-2 h-10 w-full" />
      <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton className="h-20 w-full" key={i} />
        ))}
      </div>
      <Skeleton className="mt-6 h-32 w-full" />
    </div>
  );
}
