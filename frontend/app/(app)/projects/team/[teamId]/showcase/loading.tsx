import { Skeleton } from "@/components/ui/skeleton";

export default function TeamShowcaseLoading() {
  return (
    <div className="page-container-sm">
      <Skeleton className="h-4 w-56" />
      <div className="mb-6 mt-4 flex flex-col gap-2">
        <Skeleton className="h-9 w-64" />
        <Skeleton className="h-4 w-48" />
      </div>
      <div className="grid-stats mb-8 grid gap-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton className="h-20" key={i} />
        ))}
      </div>
      <Skeleton className="mb-6 h-48 w-full" />
      <Skeleton className="mb-6 h-48 w-full" />
      <Skeleton className="h-48 w-full" />
    </div>
  );
}
