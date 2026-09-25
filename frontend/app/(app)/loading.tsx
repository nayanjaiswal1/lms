import { Skeleton } from "@/components/ui/skeleton";

// Fallback for the ~60 routes without their own loading.tsx, so a click
// swaps to a skeleton instantly instead of freezing on the old page.
export default function AppLoading() {
  return (
    <div className="page-container">
      <div className="page-header">
        <div className="flex flex-col gap-2">
          <Skeleton className="h-9 w-48" />
          <Skeleton className="h-4 w-72" />
        </div>
      </div>
      <div className="mt-8 flex flex-col gap-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton className="h-24" key={i} />
        ))}
      </div>
    </div>
  );
}
