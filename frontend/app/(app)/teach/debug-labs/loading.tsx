import { Skeleton } from "@/components/ui/skeleton";

export default function DebugLabBuilderLoading() {
  return (
    <main className="page-container flex flex-col gap-4">
      <header className="flex items-center justify-between gap-4 py-2">
        <Skeleton className="h-8 w-40" />
        <Skeleton className="h-10 w-56" />
      </header>
      <div className="flex flex-col gap-2">
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton className="h-11 w-full" key={i} />
        ))}
      </div>
    </main>
  );
}
