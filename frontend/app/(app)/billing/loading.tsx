import { Skeleton } from "@/components/ui/skeleton";

export default function BillingLoading() {
  return (
    <main className="page-container">
      <header className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-8 w-48" />
          <Skeleton className="h-4 w-72" />
        </div>
      </header>

      <div className="grid-responsive">
        {Array.from({ length: 3 }).map((_, i) => (
          <Skeleton className="h-64 rounded-lg" key={i} />
        ))}
      </div>
    </main>
  );
}
