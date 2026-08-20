import { Skeleton } from "@/components/ui/skeleton";

export default function InterviewExpLoading() {
  return (
    <main className="page-container-sm">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-8 w-64" />
          <Skeleton className="h-4 w-full max-w-md" />
        </div>
        <div className="flex gap-2">
          <Skeleton className="h-9 w-32" />
          <Skeleton className="h-9 w-40" />
        </div>
      </div>

      <Skeleton className="mb-6 h-9 w-full" />

      <div className="flex flex-col gap-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton className="h-24 w-full rounded-lg" key={i} />
        ))}
      </div>
    </main>
  );
}
