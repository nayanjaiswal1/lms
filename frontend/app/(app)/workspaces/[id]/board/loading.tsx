import { Skeleton } from "@/components/ui/skeleton";

export default function BoardLoading() {
  return (
    <div className="flex flex-col gap-4">
      <Skeleton className="h-10 w-full sm:w-2/3" />
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-7">
        {Array.from({ length: 7 }, (_, i) => (
          <Skeleton className="h-64 w-full" key={i} />
        ))}
      </div>
    </div>
  );
}
