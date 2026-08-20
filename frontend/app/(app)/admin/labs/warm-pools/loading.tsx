import { Skeleton } from "@/components/ui/skeleton";

export default function WarmPoolsLoading() {
  return (
    <div className="page-container">
      <div className="flex flex-col gap-3">
        {Array.from({ length: 5 }).map((_, i) => (
          <Skeleton className="h-14 w-full" key={i} />
        ))}
      </div>
    </div>
  );
}
