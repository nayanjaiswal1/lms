import { Skeleton } from "@/components/ui/skeleton";

export default function MentorsLoading() {
  return (
    <main className="page-container">
      <div className="mb-6 flex flex-col gap-2">
        <Skeleton className="h-8 w-28" />
      </div>

      <div className="card-grid">
        {Array.from({ length: 6 }).map((_, i) => (
          <div className="card-base flex flex-col items-center gap-3 p-6" key={i}>
            <Skeleton className="h-16 w-16 rounded-full" />
            <Skeleton className="h-4 w-24" />
            <Skeleton className="h-3 w-32" />
          </div>
        ))}
      </div>
    </main>
  );
}
