import { Skeleton } from "@/components/ui/skeleton";

export default function InterviewPrepLoading() {
  return (
    <main className="page-container">
      <div className="page-header">
        <Skeleton className="h-8 w-40" />
        <Skeleton className="h-9 w-36" />
      </div>

      <div className="flex flex-col gap-3">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton className="h-20 w-full rounded-lg" key={i} />
        ))}
      </div>
    </main>
  );
}
