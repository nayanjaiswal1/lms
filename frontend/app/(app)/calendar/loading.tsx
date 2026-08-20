import { Skeleton } from "@/components/ui/skeleton";

export default function CalendarLoading() {
  return (
    <main className="page-container">
      <div className="mb-6 flex flex-col gap-1">
        <Skeleton className="h-8 w-32" />
        <Skeleton className="h-4 w-80" />
      </div>

      <div className="mb-4 flex items-center justify-between gap-4">
        <Skeleton className="h-9 w-40" />
        <Skeleton className="h-9 w-56" />
      </div>

      <div className="grid grid-cols-7 gap-1">
        {Array.from({ length: 35 }).map((_, i) => (
          <Skeleton className="aspect-square w-full" key={i} />
        ))}
      </div>
    </main>
  );
}
