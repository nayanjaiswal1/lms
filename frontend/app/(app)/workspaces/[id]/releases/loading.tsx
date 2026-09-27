import { Skeleton } from "@/components/ui/skeleton";

export default function ReleasesLoading() {
  return (
    <div className="flex flex-col gap-6">
      <Skeleton className="h-10 w-full sm:w-1/3" />
      {Array.from({ length: 3 }, (_, i) => (
        <Skeleton className="h-28 w-full" key={i} />
      ))}
    </div>
  );
}
