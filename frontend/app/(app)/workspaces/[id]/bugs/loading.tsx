import { Skeleton } from "@/components/ui/skeleton";

export default function BugsLoading() {
  return (
    <div className="flex flex-col gap-4">
      <Skeleton className="h-4 w-64" />
      <Skeleton className="h-96 w-full" />
    </div>
  );
}
