import { Skeleton } from "@/components/ui/skeleton";

export default function TracksLoading() {
  return (
    <div className="flex flex-col gap-4">
      <Skeleton className="h-10 w-32 self-end" />
      <div className="grid gap-4 sm:grid-cols-2">
        <Skeleton className="h-40 w-full" />
        <Skeleton className="h-40 w-full" />
      </div>
    </div>
  );
}
