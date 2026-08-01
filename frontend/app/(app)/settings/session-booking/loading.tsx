import { Skeleton } from "@/components/ui/skeleton";

export default function Loading() {
  return (
    <div className="flex flex-col gap-8">
      <div className="flex flex-col gap-2">
        <Skeleton className="h-7 w-56" />
        <Skeleton className="h-4 w-full max-w-md" />
      </div>

      <div className="card-base flex flex-col gap-4 p-6">
        <Skeleton className="h-6 w-24" />
        <Skeleton className="h-16 w-full rounded-md" />
        <Skeleton className="h-16 w-full rounded-md" />
        <div className="grid gap-4 sm:grid-cols-2">
          {Array.from({ length: 5 }).map((_, i) => (
            <Skeleton className="h-16 w-full rounded-md" key={i} />
          ))}
        </div>
      </div>

      <div className="card-base flex flex-col gap-3 p-6">
        <Skeleton className="h-6 w-48" />
        <Skeleton className="h-9 w-48" />
      </div>

      <div className="flex flex-col gap-4">
        <Skeleton className="h-6 w-32" />
        <Skeleton className="h-40 w-full rounded-md" />
      </div>
    </div>
  );
}
