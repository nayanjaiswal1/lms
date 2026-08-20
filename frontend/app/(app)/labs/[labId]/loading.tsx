import { Skeleton } from "@/components/ui/skeleton";

export default function LabLoading() {
  return (
    <main className="page-container-sm flex flex-col gap-8">
      <header className="flex flex-col gap-3">
        <div className="flex items-center gap-2">
          <Skeleton className="h-5 w-16" />
          <Skeleton className="h-5 w-14" />
          <Skeleton className="h-5 w-14" />
        </div>
        <Skeleton className="h-8 w-72" />
        <Skeleton className="h-4 w-full max-w-lg" />
      </header>

      <div>
        <Skeleton className="mb-4 h-5 w-16" />
        <div className="flex flex-col gap-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton className="h-16 w-full" key={i} />
          ))}
        </div>
      </div>
    </main>
  );
}
