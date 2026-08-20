import { Skeleton } from "@/components/ui/skeleton";

export default function PracticeSessionLoading() {
  return (
    <main className="page-container">
      <div className="flex flex-col gap-2 mb-6">
        <Skeleton className="h-8 w-72" />
        <Skeleton className="h-4 w-56" />
      </div>

      <div className="flex flex-col gap-6 lg:flex-row lg:gap-8">
        <div className="order-2 flex flex-col gap-2 lg:order-1 lg:w-56">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton className="h-9 w-full" key={i} />
          ))}
        </div>

        <div className="order-1 flex-1 lg:order-2">
          <Skeleton className="h-96 w-full rounded-lg" />
        </div>
      </div>
    </main>
  );
}
