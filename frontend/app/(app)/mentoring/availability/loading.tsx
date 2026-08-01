import { Skeleton } from "@/components/ui/skeleton";

export default function Loading() {
  return (
    <main className="page-container">
      <div className="mb-8 flex flex-col gap-2">
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-4 w-full max-w-xl" />
      </div>

      <div className="mb-10 flex flex-col gap-4">
        <Skeleton className="h-6 w-40" />
        <Skeleton className="h-10 w-full sm:max-w-xs" />
        <div className="flex flex-col gap-3">
          {Array.from({ length: 7 }).map((_, i) => (
            <Skeleton className="h-20 w-full rounded-md" key={i} />
          ))}
        </div>
      </div>

      <div className="flex flex-col gap-4">
        <Skeleton className="h-6 w-48" />
        <Skeleton className="h-20 w-full rounded-md" />
        <Skeleton className="h-20 w-full rounded-md" />
      </div>
    </main>
  );
}
