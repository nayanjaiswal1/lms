import { Skeleton } from "@/components/ui/skeleton";

export default function PlanLoading() {
  return (
    <main className="page-container">
      <div className="mb-6 flex flex-col gap-1">
        <Skeleton className="h-8 w-28" />
        <Skeleton className="h-4 w-56" />
      </div>

      <div className="flex flex-col gap-6 lg:flex-row lg:gap-8">
        <div className="flex flex-1 flex-col gap-2">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton className="h-12 w-full rounded-lg" key={i} />
          ))}
        </div>
        <Skeleton className="h-96 w-full rounded-lg lg:w-80" />
      </div>
    </main>
  );
}
