import { Skeleton } from "@/components/ui/skeleton";

export default function FocusWallLoading() {
  return (
    <main className="page-container">
      <div className="mb-6 flex flex-col gap-2">
        <Skeleton className="h-8 w-40" />
        <Skeleton className="h-4 w-64" />
      </div>

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
        {Array.from({ length: 8 }).map((_, i) => (
          <Skeleton className="aspect-square w-full rounded-md" key={i} />
        ))}
      </div>
    </main>
  );
}
