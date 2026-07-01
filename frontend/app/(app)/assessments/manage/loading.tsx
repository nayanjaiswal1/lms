import { Skeleton } from "@/components/ui/skeleton";

export default function InstructorAssessmentsLoading() {
  return (
    <div className="page-container py-10">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-9 w-48" />
          <Skeleton className="h-4 w-80" />
        </div>
        <Skeleton className="h-10 w-40" />
      </div>
      <div className="card-grid mt-8">
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton className="h-44" key={i} />
        ))}
      </div>
    </div>
  );
}
