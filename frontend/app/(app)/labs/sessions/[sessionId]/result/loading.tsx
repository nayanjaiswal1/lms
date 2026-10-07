import { Skeleton } from "@/components/ui/skeleton";

export default function LabResultLoading() {
  return (
    <main className="page-container flex flex-col gap-4">
      <Skeleton className="h-20 w-full" />
      <div className="flex flex-col gap-2">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton className="h-10 w-full" key={i} />
        ))}
      </div>
      <Skeleton className="h-24 w-full" />
      <div className="grid grid-cols-1 gap-3 lg:grid-cols-2">
        <Skeleton className="h-48 w-full" />
        <Skeleton className="h-48 w-full" />
      </div>
    </main>
  );
}
