import { Skeleton } from "@/components/ui/skeleton";

export default function InterviewSkillsLoading() {
  return (
    <main className="page-container">
      <div className="page-header">
        <Skeleton className="h-8 w-40" />
      </div>

      <div className="grid-stats mb-8">
        <Skeleton className="h-20" />
        <Skeleton className="h-20" />
        <Skeleton className="h-20" />
        <Skeleton className="h-20" />
      </div>

      <Skeleton className="mb-4 h-5 w-40" />
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton className="h-28" key={i} />
        ))}
      </div>
    </main>
  );
}
