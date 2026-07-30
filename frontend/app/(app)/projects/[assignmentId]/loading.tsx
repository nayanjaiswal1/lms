import { Skeleton } from "@/components/ui/skeleton";

export default function ProjectAssignmentLoading() {
  return (
    <div className="page-container">
      <div className="page-header items-start">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-9 w-72" />
          <Skeleton className="h-4 w-48" />
          <Skeleton className="h-4 w-96" />
        </div>
        <div className="flex gap-2">
          <Skeleton className="h-10 w-28" />
          <Skeleton className="h-10 w-20" />
        </div>
      </div>
      <div className="mt-8 flex flex-col gap-4">
        <Skeleton className="h-7 w-24" />
        <div className="card-grid">
          {Array.from({ length: 2 }).map((_, i) => (
            <Skeleton className="h-52" key={i} />
          ))}
        </div>
      </div>
      <div className="mt-10 flex flex-col gap-4">
        <Skeleton className="h-7 w-48" />
        <div className="grid-responsive-2 grid gap-6">
          <Skeleton className="h-64" />
          <Skeleton className="h-64" />
        </div>
      </div>
    </div>
  );
}
