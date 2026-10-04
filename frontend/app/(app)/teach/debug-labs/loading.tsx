import { Skeleton } from "@/components/ui/skeleton";

export default function DebugLabBuilderLoading() {
  return (
    <main className="page-container flex flex-col gap-6">
      <header className="flex flex-col gap-2">
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-4 w-full max-w-lg" />
      </header>
      <div className="card-grid">
        {Array.from({ length: 3 }).map((_, i) => (
          <Skeleton className="h-36 w-full" key={i} />
        ))}
      </div>
    </main>
  );
}
