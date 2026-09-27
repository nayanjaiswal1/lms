import { Skeleton } from "@/components/ui/skeleton";

export default function SprintsLoading() {
  return (
    <div className="flex flex-col gap-6">
      <Skeleton className="h-10 w-full sm:w-1/3" />
      <Skeleton className="h-48 w-full" />
      <Skeleton className="h-24 w-full" />
    </div>
  );
}
