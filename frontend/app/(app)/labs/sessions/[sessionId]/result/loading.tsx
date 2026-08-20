import { Skeleton } from "@/components/ui/skeleton";

export default function LabResultLoading() {
  return (
    <main className="page-container-sm flex flex-col gap-8">
      <div className="card-raised flex flex-col items-center gap-4 p-8 text-center">
        <Skeleton className="h-12 w-12 rounded-full" />
        <Skeleton className="h-7 w-48" />
        <Skeleton className="h-4 w-64" />
      </div>

      <div>
        <Skeleton className="mb-4 h-5 w-24" />
        <div className="flex flex-col gap-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton className="h-14 w-full" key={i} />
          ))}
        </div>
      </div>
    </main>
  );
}
