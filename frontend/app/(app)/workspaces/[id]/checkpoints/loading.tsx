import { Skeleton } from "@/components/ui/skeleton";

export default function CheckpointsLoading() {
  return (
    <div className="flex flex-col gap-6">
      <Skeleton className="h-9 w-48" />
      <Skeleton className="h-64 w-full" />
      <Skeleton className="h-48 w-full" />
    </div>
  );
}
